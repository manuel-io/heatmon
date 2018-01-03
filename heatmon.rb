#!/usr/bin/ruby

# Copyright (C) 2017 Manuel <manuel-io@posteo.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.

require 'etc'

Threshold = 80

module Logfile
  Path = '/var/log/heatmon.log'

  unless File.exists?(Path)
    File.open(Path, 'w') do |fd|
      fd.chmod 0644
    end
  end

  def log(str)
    File.open Path, 'a' do |fd|
      fd.write Time.new.strftime("%a %d, %T, ")
      fd.write `hostname`.strip + ": "
      fd.write str + "\n"
    end
  end
end

module Sysfiles
  @@cores = `nproc`.strip
  @@frequencies = ->(n) { "/sys/devices/system/cpu/cpu#{n}/cpufreq/scaling_available_frequencies" }
  @@governor = ->(n) { "/sys/devices/system/cpu/cpu#{n}/cpufreq/scaling_governor" }
  @@range = ->(n) { "/sys/devices/system/cpu/cpu#{n}/cpufreq/scaling_available_frequencies" }
  @@speed = ->(n) { "/sys/devices/system/cpu/cpu#{n}/cpufreq/cpuinfo_cur_freq" }
  @@setspeed = ->(n) { "/sys/devices/system/cpu/cpu#{n}/cpufreq/scaling_setspeed" }

  def read(path)
    File.read(path).strip
  end

  def write(path, dat)
    File.open path, 'w' do |fd|
      fd.write dat.strip
    end
  end
end

class Temperature
 
  Files = %w|
              /sys/class/thermal/thermal_zone0/temp
              /sys/class/thermal/thermal_zone1/temp
              /sys/class/thermal/thermal_zone2/temp
              /sys/class/hwmon/hwmon0/temp1_input
              /sys/class/hwmon/hwmon1/temp1_input
              /sys/class/hwmon/hwmon2/temp1_input
              /sys/class/hwmon/hwmon0/device/temp1_input
              /sys/class/hwmon/hwmon1/device/temp1_input
              /sys/class/hwmon/hwmon2/device/temp1_input
            |

  attr_reader :current

  def initialize
    @file = Files.first
    @current = File.read(@file).to_i / 1000
    notification
  end

  private

  def notification
    Etc.passwd do |user|
      if %w|/bin/bash /usr/bin/zsh|.include? user.shell
        if @current <= 80 and @current % 10 == 0
          `su #{user.name} -c "/usr/bin/notify-send 'Temperature' '#{current} °C' --icon=dialog-information"`
        end
        if @current > 80
          `su #{user.name} -c "/usr/bin/notify-send 'Temperature' '#{current} °C' --icon=dialog-warning"`
        end
      end
   end
  end

end

class CPU

  include Logfile
  include Sysfiles

  @@temp = Temperature.new

  def self.temperature
    Temp.current
  end

  attr_reader :speed, :governor, :temperature

  def initialize(core, min, max, decrease, enlarge)
    @core = core
    @frequencies = read(@@frequencies[core]).split(/ /)
    @speed = read @@speed[core]
    @governor = read @@governor[core]
    @temperature = @@temp.current

    if @temperature > max
      decrease.call self
    end

    if @temperature < min
      enlarge.call self
    end

    log("cpu: #@core, temp: #@temperature °C, speed: #@speed Hz, governor: #@governor");
  end

  def request_less_speed()
    i = @frequencies.index @speed
    if i+1 < @frequencies.size
      write @@setspeed[@core], @frequencies[i+1]
    end
  end

  def request_more_speed()
    i = @frequencies.index @speed
    if i-1 >= 0
      write @@setspeed[@core], @frequencies[i-1]
    end
  end

  def request_governor(name)
    write @@governor[@core], name
  end
end

decrease = ->(cpu) do
  # 1. Overheat mode
  # cpu.request_governor('powersave')

  # 2.
  cpu.request_governor('userspace');
  cpu.request_less_speed
end

enlarge = ->(cpu) do
  # 1. Fallback to normal mode
  cpu.request_governor('ondemand');

  # 2.
  # cpu.request_governor('userspace');
  # cpu.request_more_speed
end

`nproc`.to_i.times do |core|
  CPU.new(core, Threshold - 10, Threshold, decrease, enlarge)
end
