require 'spec/spec_helper'

# In an attempt to avoid being fragile, this does NOT test every last byte of
# output from the #CommonOutputHandler. Rather, it uses regular expressions
# to make sure that certain key properties are satisfied.
describe AssetAggregator::OutputHandlers::CommonOutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @mtime = Time.now.to_i - 1000
    @aggregators = [ ]
    @aggregator_mtimes = { }
    @fragment_mtimes = { }
  end
  
  def make(options)
    out = AssetAggregator::OutputHandlers::CommonOutputHandler.new(@aggregate_type, @subpath, @mtime, options)
    class << out
      def extension
        "xyz"
      end
    end
    
    out.start_all
    out
  end
  
  def add(output_handler, aggregator, fragments)
    output_handler.separate_aggregators(@aggregators[-1], aggregator) unless @aggregators.empty?
    @aggregator_mtimes[aggregator] ||= (@mtime + rand(500))
    aggregator.should_receive(:max_mtime_for).at_most(:once).with(@subpath).and_return(@aggregator_mtimes[aggregator])
    @aggregators << aggregator
    output_handler.start_aggregator(aggregator)
    fragments.each_with_index do |fragment, index|
      @fragment_mtimes[fragment] ||= (@mtime + rand(500))
      fragment.should_receive(:mtime).with(no_args).at_most(:once).and_return(@fragment_mtimes[fragment])
      output_handler.separate_fragments(aggregator, fragments[index - 1], fragment) unless index == 0
      output_handler.start_fragment(aggregator, fragment)
      output_handler.fragment_content(aggregator, fragment, fragment.content)
      output_handler.end_fragment(aggregator, fragment)
    end
    output_handler.end_aggregator(aggregator)
  end
  
  def text(output_handler)
    output_handler.end_all
    output_handler.text
  end
  
  def normalized_text(output_handler)
    text(output_handler).gsub(/\s+/, ' ')
  end
  
  def retime(x)
    Regexp.escape(Time.at(x).to_s)
  end
  
  it "should put headers overall, per-aggregator, and per-fragment, when requested" do
    output_handler = make(:header_comment => :full, :aggregator_comment => :full, :fragment_comment => :full)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    aggregator1_fragments = [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'source_position_1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'source_position_2') ]
    add(output_handler, aggregators[0], aggregator1_fragments)
    aggregator2_fragments = [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'source_position_3') ]
    add(output_handler, aggregators[1], aggregator2_fragments)
    
    normalized_text(output_handler).should match(%r{foo/bar.xyz.*last\s+modified.*#{retime(@mtime)}.*aggregator1yo.*last\s+modified.*#{retime(@aggregator_mtimes[aggregators[0]])}.*source_position_1.*last\s+modified.*#{retime(@fragment_mtimes[aggregator1_fragments[0]])}.*yo ho ho.*source_position_2.*#{retime(@fragment_mtimes[aggregator1_fragments[1]])}.*and a bottle of rum.*aggregator2yo.*last\s+modified.*#{retime(@aggregator_mtimes[aggregators[1]])}.*source_position_3.*last\s+modified.*#{retime(@fragment_mtimes[aggregator2_fragments[0]])}.*a pirate's life for me}i)
  end
  
  it "should include brief headers overall, per-aggregator, and per-fragment, when requested" do
    output_handler = make(:header_comment => :brief, :aggregator_comment => :brief, :fragment_comment => :brief)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    aggregator1_fragments = [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'source_position_1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'source_position_2') ]
    add(output_handler, aggregators[0], aggregator1_fragments)
    aggregator2_fragments = [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'source_position_3') ]
    add(output_handler, aggregators[1], aggregator2_fragments)
    
    normalized_text(output_handler).should match(%r{['"]?foo/bar.xyz['"]?\s*@\s*#{@mtime}.*aggregator1yo\s*@\s*#{@aggregator_mtimes[aggregators[0]]}.*source_position_1\s*@\s*#{@fragment_mtimes[aggregator1_fragments[0]]}.*yo ho ho.*source_position_2\s*@\s*#{@fragment_mtimes[aggregator1_fragments[1]]}.*and a bottle of rum.*aggregator2yo\s*@\s*#{@aggregator_mtimes[aggregators[1]]}.*source_position_3\s*@\s*#{@fragment_mtimes[aggregator2_fragments[0]]}.*a pirate's life for me})
  end
  
  def check_substrings(source, substrings)
    last_index = -1
    last_substring = nil
    substrings.each do |substring|
      index = source.index(substring)
      raise "'#{substring}' not found in #{source}" unless index >= 0
      raise "'#{substring}' found before '#{last_substring}' in #{source}" unless index > last_index
      
      last_index = index
      last_substring = substring
    end
  end
  
  def check_encryption_call(call, expected_string)
    call.first.should == expected_string
    result = call.last
    AssetAggregator::OutputHandlers::CommonOutputHandler.decrypt('foobar123', result).should == expected_string
    result
  end
  
  it "should encrypt aggregator and fragment headers, when requested" do
    output_handler = make(:header_comment => :full, :aggregator_comment => :encrypted, :fragment_comment => :encrypted, :secret => 'foobar123')
    encryption_calls = [ ]
    encryption_proc = Proc.new { |plaintext, ciphertext| encryption_calls << [ plaintext, ciphertext ] }
    AssetAggregator::OutputHandlers::CommonOutputHandler.on_encryption(&encryption_proc)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    aggregator1_fragments = [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'source_position_1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'source_position_2') ]
    add(output_handler, aggregators[0], aggregator1_fragments)
    aggregator2_fragments = [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'source_position_3') ]
    add(output_handler, aggregators[1], aggregator2_fragments)
    
    result = normalized_text(output_handler)
    
    encryption_calls.length.should == 5
    
    aggregator1yo_encrypted = check_encryption_call(encryption_calls[0], "aggregator1yo @ #{@aggregator_mtimes[aggregators[0]]}")
    sp1_encrypted = check_encryption_call(encryption_calls[1], "source_position_1 @ #{@fragment_mtimes[aggregator1_fragments[0]]}")
    sp2_encrypted = check_encryption_call(encryption_calls[2], "source_position_2 @ #{@fragment_mtimes[aggregator1_fragments[1]]}")
    aggregator2yo_encrypted = check_encryption_call(encryption_calls[3], "aggregator2yo @ #{@aggregator_mtimes[aggregators[1]]}")
    sp3_encrypted = check_encryption_call(encryption_calls[4], "source_position_3 @ #{@fragment_mtimes[aggregator2_fragments[0]]}")
    
    check_substrings(result, [ 'foo/bar.xyz', aggregator1yo_encrypted, sp1_encrypted, 'yo ho ho', sp2_encrypted, 'and a bottle of rum', aggregator2yo_encrypted, sp3_encrypted, "a pirate's life for me" ])

    # This fails -- I believe because encrypted data ends up with metacharacters
    # that throw off the regex. Hence we check using #index, above, instead.
    # result.should match(%r{foo/bar.xyz.*#{aggregator1yo_encrypted}.*#{sp1_encrypted}.*yo ho ho.*#{sp2_encrypted}.*and a bottle of rum.*#{aggregator2yo_encrypted}.*#{sp3_encrypted}.*a pirate's life for me})
    
    %w{aggregator1yo source_position_1 source_position_2 aggregator2yo source_position_3}.each do |substring|
      result.index(substring).should be_nil
    end
  end
  
  it "should encrypt things only once" do
    encryption_call_totals = [ ]
    
    2.times do
      output_handler = make(:header_comment => :full, :aggregator_comment => :encrypted, :fragment_comment => :encrypted, :secret => 'foobar123')
      encryption_calls = [ ]
      encryption_proc = Proc.new { |plaintext, ciphertext| encryption_calls << [ plaintext, ciphertext ] }
      AssetAggregator::OutputHandlers::CommonOutputHandler.on_encryption(&encryption_proc)
    
      aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
      add(output_handler, aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'source_position_1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'source_position_2') ])
      add(output_handler, aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'source_position_3') ])
    
      normalized_text(output_handler)
      
      encryption_call_totals << encryption_calls.length
    end
    
    encryption_call_totals[0].should == encryption_call_totals[1]
  end
  
  it "should omit headers, when requested" do
    output_handler = make(:header_comment => :none, :aggregator_comment => :none, :fragment_comment => :none)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    add(output_handler, aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'source_position_1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'source_position_2') ])
    add(output_handler, aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'source_position_3') ])
    
    normalized = normalized_text(output_handler)
    [ %r{foo/bar.xyz}, %r{aggregator1yo}, %r{aggregator2yo}, %r{source_position_1}, %r{source_position_2}, %r{source_position_3} ].each do |bad_regex|
      normalized.should_not match(bad_regex)
    end
  end
end
