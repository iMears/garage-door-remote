class GarageDoorController < ApplicationController
	@@thread = nil

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
		respond_to do |format|
			format.json do
				render json: {closed: status}
			end
		end
	end

	def press
		begin
			if @@thread
				@@thread.raise "interrupt"
				@@thread = nil
			end

			self.class.mutex.synchronize do
				arduino = self.class.arduino
				arduino.digital_write 2, true
				arduino.digital_write 6, true
				arduino.analog_write 3, 128
				sleep 0.1
				arduino.digital_write 2, false

				@@thread = Thread.new do
					self.class.mutex.synchronize do
						sleep 0.4
						Thread.handle_interrupt(Exception => :never) do
							arduino.digital_write 6, false
							arduino.digital_write 3, false
						end
						2.times do
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write 6, true
								arduino.analog_write 3, 128
							end
							sleep 0.5
							Thread.handle_interrupt(Exception => :never) do
								arduino.digital_write 6, false
								arduino.digital_write 3, false
							end
						end
					end
				end
			end

			respond_to do |format|
				format.html do
					flash[:success]="Garage door activated!"
					redirect_to :root
				end
				format.json do
					render json: {'status' => 'success'}
				end
			end
		rescue => e
			respond_to do |format|
				format.html do
					flash[:danger] = "Error: #{e.message}"
					redirect_to :root
				end
				format.json do
					render json: {'status' => 'error'}
				end
			end
		end
	end
end
