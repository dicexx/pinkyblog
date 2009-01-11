#-----------------------------------------------------------
# Pinky:Blog rakefile (for windows)
#
# Requirement: Exerb, RSpec, 7-zip
# License: NYSL 0.9982 (http://www.kmonos.net/nysl/)
#-----------------------------------------------------------

ZIP = 'd:\\prog\\7-zip\\7z.exe'


require 'rake/clean'
require 'rake/packagetask'
require 'spec/rake/spectask'
require 'yaml'

SRCS = FileList.new
SRCS.include 'release/blog.cgi', 'release/blog.rb', 'release/blog_server.rb', 'release/readme.txt', 'release/pinkyblog_conf.rb'
SRCS.include 'release/lib/**/*'
SRCS.include 'release/mod/translator/**/*'
SRCS.include 'release/data/**/*'
SRCS.include 'release/res/**/*'
SRCS.include 'release/csstemplate/'
SRCS.include 'release/_doc/**/*'
SRCS.exclude 'release/_doc/exe_*.txt'

EXE_SRCS = FileList.new
EXE_SRCS.include 'release/blog_server.exe', 'release/readme.txt', 'release/pinkyblog_conf.rb'
EXE_SRCS.include 'release/lib/pinkyblog/template/*.*'
EXE_SRCS.include 'release/lib/rack/**/*.*'
EXE_SRCS.include 'release/mod/translator/**/*'
EXE_SRCS.include 'release/data/**/*'
EXE_SRCS.include 'release/res/**/*'
EXE_SRCS.include 'release/csstemplate/'
EXE_SRCS.include 'release/_doc/**/*'
EXE_SRCS.exclude 'release/_doc/license.txt'

ALL_SRCS = SRCS + EXE_SRCS

CLEAN.include '*.filelist'
CLEAN.include 'release/*.exy'
CLEAN.include 'release/res/feed/*'
CLOBBER.include 'release/*.exe'
CLEAN.include '**/*.cache'
CLEAN.include '**/data/*.json'
CLEAN.include '**/test_data/*.json'
CLOBBER.include 'pinkyblog-*.zip'
CLEAN.include '*.zip.tmp'




task :default => [:package, :patch]

desc "Clobber and package."
task :repackage => [:clobber, :package]

desc "Package all release files, with 7-zip. (default)"
task :package => ['pinkyblog-0.00.zip', 'pinkyblog-0.00exe.zip']

task :patch do |task|
	SRCS.to_a.each do |src|
		if File.file?(src) then
			dest = File.join('patch', src.slice(/^release\/(.+)/, 1))
			
			if (not File.exist?(dest) and  File.mtime(src) > Time.local(2008, 11, 2)) or
			(File.exist?(dest) and File.mtime(src) > File.mtime(dest)) then
				cp src, dest, :verbose => true
			end
			

			dest = File.join('patch_170', src.slice(/^release\/(.+)/, 1))
			
			if (not File.exist?(dest) and  File.mtime(src) > Time.local(2008, 11, 2)) or
			(File.exist?(dest) and File.mtime(src) > File.mtime(dest)) then
				cp src, dest, :verbose => true
			end

		end
	end


	EXE_SRCS.to_a.each do |src|
		if File.file?(src) then
			dest = File.join('patch_exe', src.slice(/^release\/(.+)/, 1))
			
			if (not File.exist?(dest) and  File.mtime(src) > Time.local(2008, 11, 2)) or
			(File.exist?(dest) and File.mtime(src) > File.mtime(dest)) then
				cp src, dest, :verbose => true
			end

		end
	end

end

rule '.zip' => '.filelist' do |task|
	rm(task.name, :verbose => true) if File.exist?(task.name)
	cd 'release' do
		sh "#{ZIP} a -tzip ../#{task.name} @../#{task.source}"
	end
end

rule ".filelist" => ALL_SRCS do |task|
	case task.name
	when /exe\.filelist$/
		list = EXE_SRCS
	else
		list = SRCS
	end

	open(task.name, 'w'){|f|
		f.puts(list.to_a.map{|x| x.slice(/^.+?\/(.+)/, 1)})
	}
	
	list.each do |fname|
		raise "#{fname} is not writable" unless File.writable?(fname)
	end
	
	puts "#{task.name} is maked."
end

rule '.exe' => '.exy' do |task|
	sh "exerb.bat -v #{task.source}"
end

file 'release/blog_server.exy' => FileList['release/**/*.rb']  do |task|
	cd 'release' do
		sh 'ruby -Ku -r exerb/mkexy blog_server.rb'
	end
end

desc "== spec"
task :test => :spec


Spec::Rake::SpecTask.new do |t|
	t.verbose = true
	t.spec_files = FileList['spec/**/spec_*.rb']
	t.ruby_opts = %w(-Ku)
end
