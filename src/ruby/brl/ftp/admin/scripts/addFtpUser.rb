#!/bin/env ruby
require 'fileutils'

#------------------------------------------------------------------
# Key default/base info:
#------------------------------------------------------------------
# User's home dir will be under here:
homeBase = '/usr/local/brl/data/ftp/home'
# The 'pub' and project dirs to mount are found here:
mountBase = '/usr/local/brl/data/ftp'
# Basic mount options:
mountOpts = 'ext3    bind    0 0'
# All users have these core dirs, plus mount-point dirs for any projects they are in:
userSubDirs = [ 'pub', 'inbox', 'outbox', 'working', 'finished' ]
# All users have at least these mounts, plus mounts to any projects they are in:
mounts = ['pub' ]
# What standard dirs do projects have, if we need to create them?
projSubDirs = [ 'inbox', 'outbox', 'shared']
#------------------------------------------------------------------

#------------------------------------------------------------------
# MAIN:
#------------------------------------------------------------------
puts "\n\n"
# Get username to set up:
print "Enter new FTP login:\n>> "
login = gets().strip
raise "\n\nERROR: login was empty, cannot proceed\n\n" if(login.empty? or login.nil?)
# Get CSV list of projects user will be a member of
print "Enter comma-separated list of projects this user needs access to [if any]:\n>> "
projListStr = gets().strip
projList = projListStr.split(/\,/)
projList.map! { |proj| proj.strip }

# Create home dir
baseDir = "#{homeBase}/#{login}"
unless(File.exist?(baseDir))
  FileUtils.mkdir_p(baseDir)
  FileUtils.chmod(02750, baseDir)
end

# Create subdirs (core and for project mount-points)
(userSubDirs + projList).each { |subDir|
  subDirPath = "#{baseDir}/#{subDir}"
  FileUtils.mkdir_p(subDirPath) unless(File.exist?(subDirPath))
  # Give appropriate permissions
  if(subDir == 'inbox')
    FileUtils.chmod(02770, subDirPath)
  else
    FileUtils.chmod(02750, subDirPath)
  end
}
# Give user dir tree appropriate ownership
FileUtils.chown_R('ftpAdmin', 'vsftp-virtual', baseDir)

# Create the actual project dirs, if necessary
projList.each { |proj|
  projDir = "#{mountBase}/#{proj}"
  unless(File.exist?(projDir))
    FileUtils.mkdir_p(projDir)
    projSubDirs.each { |projSubDir|
      subDirPath = "#{projDir}/#{projSubDir}"
      FileUtils.mkdir_p(subDirPath)
      if(projSubDir == 'inbox' or projSubDir == 'shared')
        FileUtils.chmod(02770, projSubDir)
      else
        FileUtils.chmod(02750, projSubDir)
      end
    }
    FileUtils.chown_R('ftpAdmin', 'vsftp-virtual', projDir)
  end
}

# Open /etc/fstab file for appending (starts at end)
fstab = File.open('/etc/fstab', 'a+')
fstab.sync = true
# Append records for mount points to /etc/fstab
(mounts + projList).each { |mount|
  record = "#{mountBase}/#{mount}    #{baseDir}/#{mount}    #{mountOpts}"
  fstab.puts(record)
}
fstab.close()
# Done making users. Mount all unmounted stuff in /etc/fstab
`mount -a`

puts "\nNOTE: you will need to add the '#{login}' user to the PAM-MySQL tables."
puts "      Below are some appropriate SQL statements for inserting this" +
     "      user with a RANDOM PASSWORD...change it if you have a Genboree" +
     "      one or something."
alphabet = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
passwd = 6.times {|ii| print alphabet[rand(alphabet.size)] }
puts "\n\nuse vsftpd ;"
puts "insert into users values (null, \"#{login}\", md5(\"#{passwd}\")) ;"
puts "\n\n"

exit(0)
