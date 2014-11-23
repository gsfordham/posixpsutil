#!/usr/bin/env ruby
# encoding: UTF-8

require_relative '../lib/posixpsutil'

def show_cpu()
  puts "The CPU number is #{CPU.cpu_count}"
  puts "Total CPU times: #{CPU.cpu_times}"
  puts "Each CPU times: #{CPU.cpu_times(true)}"
  sleep 1
  puts "The CPU percent(immediate) : #{CPU.cpu_percent(0.1)}"
  puts "The CPU percent(after a second) : #{CPU.cpu_percent(1.0)}"
  puts "Each CPU percent(immediate) : #{CPU.cpu_percent(0.1, true)}"
  puts "Each CPU percent(after a second) : #{CPU.cpu_percent(1.0, true)}"
  puts "Each CPU percent(immediate) : #{CPU.cpu_times_percent(0.1, true)}"
  puts "Each CPU percent(after a second) : #{CPU.cpu_times_percent(1.0, true)}"

end

show_cpu()
