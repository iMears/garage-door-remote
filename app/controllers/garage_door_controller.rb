class GarageDoorController < ApplicationController
	@@thread = nil
	RELAY_PIN = 2
	PIZO_PIN = 3
	LED_PIN = 6

  def index
    render json: { 'status' => 'kool' }
  end

	def self.new_connection
		arduino = ArduinoFirmata.connect
		arduino.pin_mode 12, ArduinoFirmata::INPUT
		return arduino
	end

	def self.arduino
		@@arduino ||= new_connection
	end

	def self.mutex
		@@mutex ||= Mutex.new
	end

	def status
		status = self.class.arduino.digital_read(12)
		render json: { garage_door_closed: status }
	end

	def press
		begin
			if @@thread
				@@thread.raise 'interrupt'
				@@thread = nil
			end

			self.class.mutex.synchronize do
				arduino = self.class.arduino
				arduino.digital_write RELAY_PIN, true
				arduino.digital_write LED_PIN, true
				# arduino.analog_write PIZO_PIN, 128
				sleep 0.1
				arduino.digital_write RELAY_PIN, false

				@@thread = Thread.new do
					self.class.mutex.synchronize do
						sleep 0.4
						Thread.handle_interrupt(Exception => :never) do
							arduino.digital_write LED_PIN, false
							# arduino.digital_write PIZO_PIN, false
						end
						2.times do
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write LED_PIN, true
								# arduino.analog_write PIZO_PIN, 128
							end
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write LED_PIN, false
								# arduino.digital_write PIZO_PIN, false
							end
						end
					end
				end
			end

			render json: {'status' => 'success'}
		rescue => e
			render json: {'status' => 'error', error: e.message}
		end
	end

	def garage_door_params
		 params.require(:garage_door).permit(:pizo)
	end
end
