# encoding: utf-8
# copyright: 2015, Dominik Richter
# license: All rights reserved
require 'vulcano/specfile'

module Vulcano
  # Handle Vulcano Profiles
  class Profiles
    attr_reader :profiles
    def initialize opts = {}
      @profiles = {}
      @log = Log.new(opts)
    end

    def add_folder f
      path = File::expand_path(f)
      if File.directory? path
        add_specs_in_folder path
      else
        @log.error "Path is not a folder: #{path}"
      end
      self
    end

    def valid_folder? f
      path = File::expand_path(f)
      if !File.directory? path
        return @log.error "This is not a folder: #{path}"
      else
        @log.ok "Valid directory"
      end

      md = Metadata.for_path(path)
      @log.ok "vmetadata.rb" unless md.nil? or md.incomplete?

      specs = Dir["#{path}/spec/*_spec.rb"]
      if specs.empty?
        @log.warn "No tests found in #{path}"
      end
      specs.each{|s| valid_spec? s }
    end

    def valid_spec? f
      return @log.error "Can't find spec file #{f}" unless File::file? f
      valid = true
      specs = SpecFile.from_file(f)
      meta = specs.vulcano_meta
      if meta['title'].nil?
        @log.error "Missing title in spec file #{f}"
        valid = false
      end
      if meta['copyright'].nil?
        @log.error "Missing copyright in spec file #{f}"
        valid = false
      end

      raw = File::read(f)
      describe_lines = raw.split("\n").each_with_index.
        find_all{|line,idx| line =~ /^[^"#]*describe.*do(\s|$)/ }.
        map{|x| x[1]+1 }

      unless meta['checks'][''].nil?
        @log.error "Please configure IDs for all rules."
      end

      invalid = lambda {|msg|
        @log.error msg
        valid = false
      }

      meta['checks'].each do |k,v|
        invalid("Missing impact for rule #{k}") if v['impact'].nil?
        invalid("Impact cannot be larger than 1.0 for rule #{k}") if v['impact'] > 1.0
        invalid("Impact cannot be less than 0.0 for rule #{k}") if v['impact'] < 0.0
        invalid("Missing title for rule #{k}") if v['title'].nil? || v['title'] == k
        invalid("Missing description for rule #{k}") if v['desc'].nil?
      end

      @log.ok "Valid spec file in #{f}" if valid && specs.instance_variable_get(:@invalid_calls).empty?
    end

    private

    def add_specs_in_folder path
      allchecks = {}

      Dir["#{path}/spec/*_spec.rb"].each do |specfile|
        rel_path = specfile.sub(File.join(path,''), '')
        specs = SpecFile.from_file(specfile)
        allchecks[rel_path] = specs.vulcano_meta
      end

      res = Metadata.for_path(path, @log).dict
      res['checks'] = allchecks
      @profiles = res
    end

  end
end
