# $Id$

#
# This class represents the INI file and can be used to parse, modify,
# and write INI files.
#
module IniTools
class IniFile

  # :stopdoc:
  class Error < StandardError; end
  VERSION = '0.2.2'
  # :startdoc:

  #
  # call-seq:
  #    IniFile.load( filename )
  #    IniFile.load( filename, options )
  #
  # Open the given _filename_ and load the contetns of the INI file.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
  #
  def self.load( filename, opts = {} )
    new(filename, opts)
  end

  #
  # call-seq:
  #    IniFile.new( filename )
  #    IniFile.new( filename, options )
  #
  # Create a new INI file using the given _filename_. If _filename_
  # exists and is a regular file, then its contents will be parsed.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
  #
  def initialize( filename_or_io, opts = {} )
    @fn = filename_or_io
    @comment = opts[:comment] || ';'
    @param = opts[:parameter] || '='
    @ini = Hash.new {|h,k| h[k] = Hash.new}
    @ini_comments = Hash.new {|h,k| h[k] = Hash.new}
    @ini_section_comments = Hash.new {|h,k| h[k] = Array.new}

    @rgxp_comment = %r/\A\s*\z|\A\s*[#{@comment}](.*)\z/
    @rgxp_section = %r/\A\s*\[([^\]]+)\]/o
    @rgxp_param   = %r/\A([^#{@param}]+)#{@param}(.*)\z/

    parse
  end
  #
  # call-seq:
  #    write
  #    write( filename )
  #
  # Write the INI file contents to the filesystem. The given _filename_
  # will be used to write the file. If _filename_ is not given, then the
  # named used when constructing this object will be used.
  #
  def write( filename = nil )
    @fn = filename unless filename.nil?

    ::File.open(@fn, 'w') do |f|
      @ini.each do |section,hash|
        f.puts "[#{section}]"
        hash.each {|param,val| f.puts "#{param} #{@param} #{val}"}
        f.puts
      end
    end
    self
  end
  alias :save :write

  #
  # call-seq:
  #    each {|section, parameter, value| block}
  #
  # Yield each _section_, _parameter_, _value_ in turn to the given
  # _block_. The method returns immediately if no block is supplied.
  #
  def each
    return unless block_given?
    @ini.each do |section,hash|
      hash.each do |param,val|
        yield section, param, val
      end
    end
    self
  end

  #
  # call-seq:
  #    each_section {|section| block}
  #
  # Yield each _section_ in turn to the given _block_. The method returns
  # immediately if no block is supplied.
  #
  def each_section
    return unless block_given?
    @ini.each_key {|section| yield section}
    self
  end

  #
  # call-seq:
  #    delete_section( section )
  #
  # Deletes the named _section_ from the INI file. Returns the
  # parameter / value pairs if the section exists in the INI file. Otherwise,
  # returns +nil+.
  #
  def delete_section( section )
    @ini.delete section.to_s
  end

  #
  # call-seq:
  #    ini_file[section]
  #
  # Get the hash of parameter/value pairs for the given _section_. If the
  # _section_ hash does not exist it will be created.
  #
  def []( section )
    return nil if section.nil?
    @ini[section.to_s]
  end

  #
  # call-seq:
  #    has_section?( section )
  #
  # Returns +true+ if the named _section_ exists in the INI file.
  #
  def has_section?( section )
    @ini.has_key? section.to_s
  end

  #
  # call-seq:
  #    sections
  #
  # Returns an array of the section names.
  #
  def sections
    @ini.keys
  end


  #
  # call-seq:
  #    ini_file.comments(section)
  #
  # Get an array of comments for the _section_. 
  #
  def comments( section )
    return nil if section.nil?
    
    @ini_section_comments[section.to_s]

  end
  #
  # call-seq:
  #    ini_file.comment(section)
  #
  # Get the possibly multiline comment for the _section_. 
  #
  def comment( section , param)
    return nil if section.nil? ||  !@ini_comments.has_key?(section.to_s)
    
    @ini_comments[section][param]
  end

  #
  # call-seq:
  #    has_comment?( section, param )
  #
  # Returns +true+ if the named _section_ has a comment
  #
  def has_comment?( section , param)
    if @ini_comments.has_key? section.to_s
    	@ini_comments[section.to_s].has_key?(param.to_s)
    else
    	false
    end
  end

  #
  # call-seq:
  #    has_comments?( section )
  #
  # Returns +true+ if the named _section_ has comments
  #
  def has_comments?( section)
    @ini_section_comments.has_key? section.to_s
  end

	

  #
  # call-seq:
  #    freeze
  #
  # Freeze the state of the +IniFile+ object. Any attempts to change the
  # object will raise an error.
  #
  def freeze
    super
    @ini.each_value {|h| h.freeze}
    @ini.freeze
    self
  end

  #
  # call-seq:
  #    taint
  #
  # Marks the INI file as tainted -- this will traverse each section marking
  # each section as tainted as well.
  #
  def taint
    super
    @ini.each_value {|h| h.taint}
    @ini.taint
    self
  end

  #
  # call-seq:
  #    dup
  #
  # Produces a duplicate of this INI file. The duplicate is independent of the
  # original -- i.e. the duplicate can be modified without changing the
  # orgiinal. The tainted state of the original is copied to the duplicate.
  #
  def dup
    other = super
    other.instance_variable_set(:@ini, Hash.new {|h,k| h[k] = Hash.new})
    @ini.each_pair {|s,h| other[s].merge! h}
    other.taint if self.tainted?
    other
  end

  #
  # call-seq:
  #    clone
  #
  # Produces a duplicate of this INI file. The duplicate is independent of the
  # original -- i.e. the duplicate can be modified without changing the
  # orgiinal. The tainted state and the frozen state of the original is copied
  # to the duplicate.
  #
  def clone
    other = dup
    other.freeze if self.frozen?
    other
  end

  #
  # call-seq:
  #    eql?( other )
  #
  # Returns +true+ if the _other_ object is equivalent to this INI file. For
  # two INI files to be equivalent, they must have the same sections with  the
  # same parameter / value pairs in each section.
  #
  def eql?( other )
    return true if equal? other
    return false unless other.instance_of? self.class
    @ini == other.instance_variable_get(:@ini)
  end
  alias :== :eql?


  private
  #
  # call-seq
  #    parse
  #
  # Parse the ini file contents.
  #
  def parse
    if @fn.kind_of?(String) 
      return unless ::Kernel.test ?f, @fn
      section = nil
  
      ::File.open(@fn, 'r') do |f|
        parse_io(f)
      end  # File.open
    elsif @fn.kind_of?(File)
        parse_io(@fn)
    elsif @fn.kind_of?(IO)
      parse_io(@fn)
    end

  end
  def parse_io(io)
  	  unmatched_comments = []
  	  section = nil
  	  section_name = nil
  	  section_comments = nil
  	  section_attr_comments = nil
      while line = io.gets
        line = line.chomp
        
        case line
        # ignore blank lines and comment lines
	     	when @rgxp_comment: 
	     			unmatched_comments << $1.strip  if !$1.nil?

        # this is a section declaration
        when @rgxp_section: 
        	section_name = $1.strip
        	section = @ini[section_name]
        	section_attr_comments = @ini_comments[section_name]
        	if unmatched_comments.size > 0
        		@ini_section_comments[section_name] = unmatched_comments
        		unmatched_comments = []
        	end

        # otherwise we have a parameter
        when @rgxp_param
          begin
          	unmatched_comments = []
          	attr_name = $1.strip
          	attr_value = $2
          	if !attr_value.nil? && attr_value != ""
          		value, comment = attr_value.split(/[#{@comment}]/)
          		if !comment.nil?
	          			section_attr_comments[attr_name] = comment.strip
	          	end
          		value = value.strip
          	else
          		value = attr_value
          	end
            section[attr_name] = value
          rescue NoMethodError
            raise Error, "parameter encountered before first section #{$!}"
          end

        else
          raise Error, "could not parse line '#{line}"
        end
      end  # while	
  end
end  # class IniFile
end
# EOF
