require 'socket'
require 'posixpsutil/linux/process'

include PosixPsutil

class TestLinuxProcess < MiniTest::Test
  # we need a threshold
  THRESHOLD = 0.0101

  def setup
    @process = PlatformSpecificProcess.new(Process.pid)
  end

  def test_cmdline
    # should be run with `rake test`
    assert_equal '-Ilib:lib:test', @process.cmdline()[1]
  end

  def test_connections
    Socket.pair(:UNIX, :STREAM, 0)
    connections = @process.connections(:all)
    assert_equal 2, connections.size
    assert_equal 0, @process.connections(:inet).size
    assert_equal 2, @process.connections(:unix).size
    refute_respond_to connections[0], :pid
    assert_respond_to connections[0], :fd
    assert_respond_to connections[0], :family
    assert_respond_to connections[0], :type
    assert_respond_to connections[0], :laddr
    assert_respond_to connections[0], :raddr
    assert_respond_to connections[0], :status
  end

  def test_connections_for_inet
    begin
      # ping www.bing.com to create a tcp connection
      Socket.tcp("www.bing.com", 80) {|sock|
        assert_equal 1, @process.connections(:inet).size
      }
    rescue SocketError # if there is no network connection, ignore the result
    end
  end

  def test_connections_if_interface_not_supported
    assert_raises ArgumentError do
      @process.connections('inet')
    end
  end

  def test_cpu_times
    cpu_times = @process.cpu_times
    assert_in_delta Process.times.utime, cpu_times.user, THRESHOLD
    assert_in_delta Process.times.stime, cpu_times.system, THRESHOLD
  end

  def test_cpu_affinity
    affinity = @process.cpu_affinity
    assert affinity.is_a?(Array)
    assert !affinity.empty?
  end

  def test_cpu_affinity=
    before = @process.cpu_affinity
    if before[0] == 0
      after = [1]
    else
      after = [0]
    end
    @process.cpu_affinity=after
    assert_equal after, @process.cpu_affinity
  end

  def test_create_time
    assert @process.create_time() < Time.now.to_f
  end

  def test_cwd
    assert_equal Dir.pwd, @process.cwd()
  end

  def test_exe
    assert @process.exe().start_with?("/usr/bin/ruby")
  end

  def test_gids
    gids = @process.gids
    assert_equal Process::GID.rid, gids.real
    assert_equal Process::GID.eid, gids.effective
    assert_respond_to gids, :saved
  end

  def test_io_counters
    # r means read while w means write
    io_counters = @process.io_counters
    assert_respond_to io_counters, :rcount
    assert_respond_to io_counters, :wcount
    assert_respond_to io_counters, :rbytes
    assert_respond_to io_counters, :wbytes
  end

  def test_ionice
    ionice = @process.ionice
    assert [0, 1, 2, 3, 4].include? ionice.ioclass
    # Since the ioclass output is depending on your system language, 
    # we can't parse it correctly, so just parse the value
    value = IO.popen("ionice -p #{Process.pid}").read.split.last.to_i
    assert_equal value, ionice.value
  end

  def test_set_ionice
    # best-effort, highest level
    #@process.set_ionice(PosixPsutil::IOPRIO_CLASS_BE, 0) 
    # or
    @process.set_ionice(:be, 0)
    ionice = @process.ionice
    assert_equal 2, ionice.ioclass
    assert_equal 0, ionice.value
  end

  def test_memory_info
    memory_info = @process.memory_info
    # Virtual Memory Size
    assert_respond_to memory_info, :vms
    # Resident Set Size
    assert_respond_to memory_info, :rss
  end

  def test_memory_info_ex
    memory_info = @process.memory_info
    memory_info_ex = @process.memory_info_ex
    assert_respond_to memory_info_ex, :shared
    assert_respond_to memory_info_ex, :text
    assert_respond_to memory_info_ex, :lib
    assert_respond_to memory_info_ex, :data
    assert_respond_to memory_info_ex, :dirty
    assert_in_delta memory_info.vms, memory_info_ex.vms, 
      memory_info_ex.vms * THRESHOLD
    assert_in_delta memory_info.rss, memory_info_ex.rss, 
      memory_info_ex.rss * THRESHOLD
  end

  def test_name
    # current process
    assert @process.name().start_with?('ruby')
  end

  def test_nice
    @process.nice
  end

  def test_nice=
    @process.nice=1
    assert_equal(1, @process.nice)
  end

  def test_num_ctx_switches
    num_ctx_switches = @process.num_ctx_switches
    assert_respond_to num_ctx_switches, :voluntary
    assert_respond_to num_ctx_switches, :involuntary
  end

  def test_num_fds
    @process.num_fds
  end

  def test_num_threads
    # the result is different from Thread.list.size, because
    # it shows the number of threads in system size instead of ruby size
    @process.num_threads
  end

  def test_open_files
    @process.open_files
  end

  def test_pmmap_ext
    maps = @process.memory_maps
    ext = @process.pmmap_ext(maps)
    pmmap_ext_items = ['addr', 'perms', 'path', 'rss', 'size', 'pss', 
                 'shared_clean', 'shared_dirty', 'private_clean', 
                 'private_dirty', 'referenced', 'anonymous', 'swap']
    pmmap_ext_items.each do |item|
      assert_respond_to ext[0], item.to_sym
    end
  end

  def test_pmmap_grouped
    maps = @process.memory_maps
    ext = @process.pmmap_grouped(maps)
    pmmap_grouped_items = ['path', 'rss', 'size', 'pss', 
                 'shared_clean', 'shared_dirty', 'private_clean', 
                 'private_dirty', 'referenced', 'anonymous', 'swap']
    pmmap_grouped_items.each do |item|
      assert_respond_to ext[0], item.to_sym
    end
  end

  def test_ppid
    assert_equal Process.ppid, @process.ppid
  end

  def test_rlimit
    # Number of open files
    rlimit = @process.rlimit(PosixPsutil::RLIMIT_NOFILE)
    # or
    #rlimit = @process.rlimit(:nofile)
    assert rlimit.key? :soft
    assert rlimit.key? :hard

    rlimit[:soft] = rlimit[:hard]
    new_rlimit = @process.rlimit(7, rlimit)
    assert_equal rlimit, new_rlimit
  end

  def test_status
    assert_equal 'running', @process.status()
  end

  def test_terminal
    tty = @process.terminal()
    assert tty.start_with?('/dev/tty') || tty.start_with?('/dev/pts/')
  end

  def test_threads
    threads = @process.threads
    assert_equal @process.num_threads, @process.threads.size
    assert_respond_to threads.first, :thread_id
    assert_respond_to threads.first, :user_time
    assert_respond_to threads.first, :system_time
  end

  def test_time_used
    former_process_time_used = @process.time_used()
    assert @process.time_used() >= former_process_time_used
  end

  def test_uids
    uids = @process.uids
    assert_equal Process::UID.rid, uids.real
    assert_equal Process::UID.eid, uids.effective
    assert_respond_to uids, :saved
  end

end

class TestLinuxProcessErrorHandler < MiniTest::Test
  def test_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).name()
    end
  end 

  def test_premission_denied
    assert_raises AccessDenied do
      PlatformSpecificProcess.new(1).exe()
    end
  end

  def test_exe_access_denied
    assert_raises AccessDenied do
      PlatformSpecificProcess.new(1).exe()
    end
  end
  
  def test_exe_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).exe()
    end
  end

  def test_assert_process_exists
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).connections()
    end
  end

  def test_get_cpu_affinity_on_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).cpu_affinity
    end
  end

  def test_set_cpu_affinity_on_no_such_process
    assert_raises NoSuchProcess do
      PlatformSpecificProcess.new(99999).cpu_affinity=[1]
    end
  end

  def test_set_cpu_affinity_access_denied
    assert_raises AccessDenied do
      PlatformSpecificProcess.new(1).cpu_affinity=[1]
    end
  end

  def test_set_cpu_affinity_too_long
    # assert raise nothing
    PlatformSpecificProcess.new(Process.pid).cpu_affinity=[1, 1, 1, 1]
  end

  def test_set_cpu_affinity_affinity_too_large
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).cpu_affinity=[1000]
    end
  end

  def test_set_ionice_argument_error
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).set_ionice(1, 5.5)
    end
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).set_ionice(4, 0)
    end
  end

  def test_set_nice_argument_error
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).nice = 0.5
    end
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).nice = -21
    end
  end

  def test_set_rlimit_argument_error
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).rlimit(1, [20, 1])
    end
    assert_raises ArgumentError do
      PlatformSpecificProcess.new(Process.pid).rlimit(1, {:soft => 1})
    end
  end
end
