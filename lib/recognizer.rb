class Recognizer
  attr :result
  attr :queue
  attr :pipeline
  attr :appsrc
  attr :asr
  attr :clock
  
  def initialize
    @result = ""
    # construct pipeline
    @pipeline = Gst::Parse.launch("appsrc name=appsrc ! audioconvert ! audioresample ! pocketsphinx name=asr ! fakesink")
    @clock = Gst::SystemClock.new
    # define input audio properties
    @appsrc = @pipeline.get_child("appsrc")
    caps = Gst::Caps.parse("audio/x-raw-int,rate=16000,channels=1,signed=true,endianness=1234,depth=16,width=16")
    @appsrc.set_property("caps", caps)
    
    # define behaviour for ASR output
    @asr = @pipeline.get_child("asr")
    @asr.signal_connect('partial_result') { |asr, text, uttid| 
      #puts "PARTIAL: " + text 
      @result = text 
    }
    @asr.signal_connect('result') { |asr, text, uttid| 
      #puts "FINAL: " + text 
      @result = text  
      @queue.push(1)
    }
    
    @queue = Queue.new
    # This returns when ASR engine has been fully loaded
    @asr.set_property('configured', true)
  end
    
  # Call this before starting a new recognition
  def clear
    @result = ""
    queue.clear
    pipeline.pause
  end
  
  # Feed new chunk of audio data to the recognizer
  def feed_data(data)
    pipeline.play      
    buffer = Gst::Buffer.new
    buffer.data = data
    buffer.timestamp = clock.time
    appsrc.push_buffer(buffer)
  end
  
  # Notify recognizer of utterance end
  def close_stream
    appsrc.end_of_stream
  end
  
  # Wait for the recognizer to recognize the current utterance
  # Returns the final recognition result
  def wait_final_result
    queue.pop
    pipeline.stop
    return result
  end
  
  def end_feed
    close_stream
    wait_final_result
  end
end
