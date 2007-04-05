require 'fileutils'

module Spec
  class Translator
    def translate(from, to)
      from = File.expand_path(from)
      to = File.expand_path(to)
      if File.directory?(from)
        translate_dir(from, to)
      elsif(from =~ /\.rb$/)
        translate_file(from, to)
      end
    end
    
    def translate_dir(from, to)
      FileUtils.mkdir_p(to) unless File.directory?(to)
      Dir["#{from}/*"].each do |sub_from|
        path = sub_from[from.length+1..-1]
        sub_to = File.join(to, path)
        translate(sub_from, sub_to)
      end
    end

    def translate_file(from, to)
      translation = ""
      File.open(from) do |io|
        io.each_line do |line|
          translation << translate_line(line)
        end
      end
      File.open(to, "w") do |io|
        io.write(translation)
      end
    end

    def translate_line(line)
      return line if line =~ /(should_not|should)_receive/
      
      if line =~ /(.*\.)(should_not|should)(?:_be)(?!_)(.*)/m
        pre = $1
        should = $2
        post = $3
        be_or_equal = post =~ /(<|>)/ ? "be" : "equal"
        
        return "#{pre}#{should} #{be_or_equal}#{post}"
      end
      
      if line =~ /(.*\.)(should_not|should)_(?!not)\s*(.*)/m
        pre = $1
        should = $2
        post = $3
        
        post.gsub!(/^raise/, 'raise_error')
        post.gsub!(/^throw/, 'throw_symbol')
        
        unless standard_matcher?(post)
          post = "be_#{post}"
        end
        
        # Add parenthesis
        post.gsub!(/^(\w+)\s+([\w|\.|\,|\(.*\)|\'|\"|\:|@| ]+)(\})/, '\1(\2)\3') # inside a block
        post.gsub!(/^(\w+)\s+([\w|\.|\,|\(.*\)|\{.*\}|\'|\"|\:|@| ]+)/, '\1(\2)')
        post.gsub!(/(\s+\))/, ')')
        post.gsub!(/\)\}/, ') }')
        post.gsub!(/^(\w+)\s+(\/.*\/)/, '\1(\2)') #regexps
        line = "#{pre}#{should} #{post}"
      end

      line
    end
    
    def standard_matcher?(matcher)
      patterns = [
        /^be/, 
        /^be_close/,
        /^eql/, 
        /^equal/, 
        /^has/, 
        /^have/, 
        /^change/, 
        /^include/,
        /^match/, 
        /^raise_error/, 
        /^respond_to/, 
        /^satisfy/, 
        /^throw_symbol/,
        # Extra ones that we use in spec_helper
        /^pass/,
        /^fail/,
        /^fail_with/,
      ]
      matched = patterns.detect{ |p| matcher =~ p }
      !matched.nil?
    end
    
  end
end