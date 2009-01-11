require 'stringio'
require 'wx'
require 'wxconstructor'

class App < Wx::App
	def on_init
		evt_idle { Thread.pass }
		@frame = MainFrame.new(nil)
		@frame.show
	end
	
end

class MainFrame < Wx::Frame
	def initialize(*args)
		super
		self.title = 'Pinky:blog スタンドアロンサーバー'
		
		construct_children{|frame|
			sz = hbox_sizer do
				locate 1
				widget Wx::Panel do
					vbox_sizer do
						static_hbox_sizer '起動ポート' do
							stretch_spacer(1)
							widget Wx::TextCtrl, :value => '8888'
							stretch_spacer(1)
						end
					
						locate 0, Wx::EXPAND
						hbox_sizer do |sz|
							stretch_spacer(1)
							widget Wx::Button, :label => 'サーバー起動' do |button|
								frame.evt_button(button, :on_start_server)
							end
							stretch_spacer(1)
						end
					end
				end
			end
			
			sz.fit(frame)
		}
		
	
	end
	
	def on_start_server(evt)
		BootingDialog.new(self).show_modal
	end

end

class BootingDialog < Wx::Dialog
	def initialize(*args)
		super
		self.title = 'サーバー起動中'

		dlg = self
		console = nil
		construct_children{|dlg|
			sz = vbox_sizer do
				console = widget Wx::StaticText, :size => [360, 200], :label => '', :style => Wx::SUNKEN_BORDER|Wx::VSCROLL|Wx::ST_NO_AUTORESIZE do
				end
				
				locate 0, Wx::EXPAND
				hbox_sizer do
					stretch_spacer(1)
					widget Wx::Button, :label => '停止' do |button|
						dlg.evt_button(button, :on_stop)
					end
					stretch_spacer(1)
				end
			end
			
			sz.fit(dlg)
		}
		system('start ruby blog_standalone.rb')
		return
		
		$stderr = ConsoleIO.new(console)

		#Wx::Timer.every(1) do
			# no act (timer loop for thread)
		#end
		
		@server_thread = Thread.new do
			require 'blog'
		
			app = Rack::Builder.new{
				use Rack::CommonLogger
				use Rack::ShowExceptions
				use Rack::Lint
				use Rack::ShowStatus
				
				run BlogCaller.new
				
			}
			
		
			Rack::Handler::WEBrick.run(app, :Port => 8888){|s|
				@server = s
			}
		end
		
		
		
	end
	
	def on_stop
		$stderr = STDERR
		#$server.shutdown
		@server.shutdown
		@server_thread.kill
		close
	end
end

class ConsoleIO < StringIO
	def initialize(widget)
		super()
		@console_widget = widget
	end
	
	def write(str)
		super
		$stdout.write(str)
		@console_widget.label = self.string.delete("^0-9a-zA-Z\n\t: /")
		@console_widget.refresh
		@console_widget.update_window_ui
	end
end

App.new.main_loop
