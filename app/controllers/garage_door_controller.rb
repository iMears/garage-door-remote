class GarageDoorController < ApplicationController
	@@thread = nil
	RELAY_PIN = 2
	PIZO_PIN = 3
	LED_PIN = 6
	DOOR_SENSOR = 12

	def self.new_connection
		arduino = ArduinoFirmata.connect
		arduino.pin_mode DOOR_SENSOR, ArduinoFirmata::INPUT # Set door sensor to be an input pin
		return arduino
	end

	def self.arduino
		@@arduino ||= new_connection
	end

	def self.mutex
		@@mutex ||= Mutex.new
	end

	def status
		garage_door_closed = self.class.arduino.digital_read(DOOR_SENSOR)
    render json: { garage_door_closed: garage_door_closed }
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
				arduino.analog_write PIZO_PIN, 128 if params[:pizo]
				sleep 0.1
				arduino.digital_write RELAY_PIN, false

				@@thread = Thread.new do
					self.class.mutex.synchronize do
						sleep 0.4
						Thread.handle_interrupt(Exception => :never) do
							arduino.digital_write LED_PIN, false
							arduino.digital_write PIZO_PIN, false if params[:pizo]
						end
						2.times do
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write LED_PIN, true
								arduino.digital_write PIZO_PIN, 128 if params[:pizo]
							end
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write LED_PIN, false
								arduino.digital_write PIZO_PIN, false if params[:pizo]
							end
						end
					end
				end
			end

			render json: {'status' => 'success'}
		rescue => e
			render json: {'status' => 'error', message: e.message}
		end
	end

	def garage_door_params
		params.require(:garage_door).permit(:pizo)
	end
end
