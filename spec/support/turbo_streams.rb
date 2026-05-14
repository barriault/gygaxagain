# Capture Turbo::StreamsChannel.broadcast_replace_to / broadcast_append_to /
# broadcast_remove_to calls for assertion in job specs without standing up
# an ActionCable subscriber.
module TurboStreamsCaptureHelpers
  def captured_turbo_broadcasts
    @captured_turbo_broadcasts ||= []
  end

  def install_turbo_capture!
    %i[broadcast_replace_to broadcast_append_to broadcast_remove_to broadcast_update_to].each do |method|
      allow(Turbo::StreamsChannel).to receive(method) do |*args, **kwargs|
        captured_turbo_broadcasts << { method: method, args: args, kwargs: kwargs }
      end
    end
  end
end

RSpec.configure do |c|
  c.include TurboStreamsCaptureHelpers, type: :job
end
