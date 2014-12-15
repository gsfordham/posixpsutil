require 'ostruct'
require 'rbconfig'
require_relative 'psutil_error'

os = RbConfig::CONFIG['host_os']
case os
  when /darwin|mac os|solaris|bsd/
    require_relative 'posix_process'
  when /linux/
    require_relative 'linux_process'
  else
    raise RuntimeError, "unknown os: #{os.inspect}"
end

# As there is a Process Module in ruby, I change the name to Processes
class Processes
   # Represents an OS process with the given PID.
   # If PID is omitted current process PID (Process.pid) is used.
   # Raise NoSuchProcess if PID does not exist.
   #
   # Note that most of the methods of this class do not make sure
   # the PID of the process being queried has been reused over time.
   # That means you might end up retrieving an information referring
   # to another process in case the original one this instance
   # refers to is gone in the meantime.
   #
   # The only exceptions for which process identity is pre-emptively
   # checked and guaranteed are:

   #  - parent()
   #  - children()
   #  - nice() (set)
   #  - ionice() (set)
   #  - rlimit() (set)
   #  - cpu_affinity (set)
   #  - suspend()
   #  - resume()
   #  - send_signal()
   #  - terminate()
   #  - kill()

   # To prevent this problem for all other methods you can:
   #   - use is_running() before querying the process
   #   - if you're continuously iterating over a set of Process
   #     instances use process_iter() which pre-emptively checks
   #     process identity for every instance
  
  attr_reader :identity
  attr_reader :pid

  def initialize(pid=nil)
    pid = Process.pid unless pid
    @pid = pid
    raise ArgumentError.new("pid must be 
                            a positive integer (got #{@pid})") if @pid <= 0
    @name = nil
    @exe = nil
    @create_time = nil 
    @gone = false
    @hash = nil
    @proc = PlatformSpecificProcess.new(@pid)
    @last_sys_cpu_times = nil
    @last_proc_cpu_times = nil
    begin
      create_time
    rescue AccessDenied
      # we should never get here as AFAIK we're able to get
      # process creation time on all platforms even as a
      # limited user
    rescue NoSuchProcess
      msg = "no process found with pid #{@pid}"
      raise NoSuchProcess(pid:@pid, msg:msg)
    end
    # This part is supposed to indentify a Process instance
    # univocally over time (the PID alone is not enough as
    # it might refer to a process whose PID has been reused).
    # This will be used later in == and is_running().
    @identity = [@pid, @create_time]
  end

  def to_s
    begin
      return "(pid=#{@pid}, name=#{name()})"
    rescue NoSuchProcess
      return "(pid=#{@pid} (terminated))"
    rescue AccessDenied
      return "(pid=#{@pid})"
    end
  end

  def inspect
    self.to_s.inspect
  end

  def ==(other)
    # Test for equality with another Process object based
    # on PID and creation time.
    return self.class == other.class && @identity == other.identity
  end
  alias_method :eql?, :==

  def !=(other)
    return !(self == other)
  end

  # utility methods
  
  # Utility method returning process information as a hash.
  # Unlike normal to_hash method, this method can accept two params,
  # attrs and default
  #
  # If 'attrs' is specified it must be a list of strings
  # reflecting available Process class' attribute names
  # (e.g. ['cpu_times', 'name']) else all public (read
  # only) attributes are assumed.

  # 'default' is the value which gets assigned in case
  # AccessDenied  exception is raised when retrieving that
  # particular process information.
  def to_hash(attrs=[], default={})
    included_name = []
    ret = {}
    attrs = included_name if attrs == []
    attrs.each do |attr|
      ret[attr] = nil
      begin
        ret[attr] = attr()
      rescue AccessDenied
        ret[attr] = default[attr] if default.has_key? attr
      rescue NotImplementedError
        raise if attrs
        ret[attr] = default[attr] if default.has_key? attr
      end
    end
    ret
  end

  # Return the parent process as a Processes object pre-emptively
  # checking whether PID has been reused.
  # If no parent is known return nil.
  def parent
    ppid = ppid()
    if ppid 
      begin
        parent = Processes.new ppid
        return parent if parent.create_time() <= create_time()
      rescue NoSuchProcess
        # ignore ...
      end
    end
    return nil
  end

  # Return if this process is running.
  # It also checks if PID has been reused by another process in
  # which case return false.
  def is_running
    return false if @gone
    begin
      return self == Processes(@pid)
    rescue NoSuchProcess
      @gone = true
      return false
    end
  end

  # actual API
  
  def ppid
    @proc.ppid
  end

  # The process name. The return value is cached after first call.
  def name
    unless @name
      @name = @proc.name()
      if @name.length >= 15
        begin
          cmdline = cmdline()
        rescue AccessDenied
          cmdline = []
        end
        if cmdline
          extended_name = File.basename(cmdline[0])
          @name = extended_name if extended_name.start_with?(@name)
        end
      end
    end
    @name
  end

  # The command line this process has been called with.
  # An array will be returned
  def cmdline
    @proc.cmdline()
  end

  def create_time
    nil
  end

end

