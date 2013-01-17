module ForeclosureHelpers
	def load_foreclosure(cdc_number, client=nil)
		begin
			client = Savon.client ENV['SHERIFF_WSDL'] if client.nil?

			response = client.request 'm:GetForeclosure' do 
				http.headers['SOAPAction'] = ENV['SHERIFF_ACTION']
				soap.namespaces['xmlns:m'] = ENV['SHERIFF_NS']
				soap.body = {'m:cdcCaseNumber' => cdc_number, 'm:key' => ENV['SHERIFF_PASSWORD'] }
			end
			puts "Requesting cdcCaseNumber => #{cdc_number}"
			foreclosure = response.hash[:envelope][:body][:get_foreclosure_response][:get_foreclosure_result][:foreclosure]

			if foreclosure
				puts foreclosure
				sale_dt = nil
				sale_dt = DateTime.strptime(foreclosure[:sale_date], '%m/%d/%Y %H:%M:%S %p') unless foreclosure[:sale_date] == "Null"

				addr = {address_long: nil, house_num: nil, street_type: nil, street_name: nil}

				if foreclosure[:property_address]
					addr[:address_long] = foreclosure[:property_address]
					addr[:address_long] = addr[:address_long].chop if addr[:address_long].end_with?(".")
					addr[:house_num] = addr[:address_long].split(' ')[0]
					addr[:street_type] = AddressHelpers.get_street_type addr[:address_long] 
					addr[:street_name] = AddressHelpers.get_street_name addr[:address_long]
				end
				status = foreclosure[:sale_status]
				if sale_dt
					f = Event.where("name = 'Foreclosure' and details like '%#{cdc_number}%'").first
					if f
						f.update_attributes(status: status, date: sale_dt)
					else
						# addresses = AddressHelpers.find_address(location)
      #   				address = addresses.first if addresses
						Event.create(:name => 'Foreclosure', :date => sale_dt, :status => status, :details => {address: addr, title: foreclosure[:case_title][0..254], cdc_case_number: foreclosure[:cdc_case_number], defendant: foreclosure[:defendant][0..254], plaintiff: foreclosure[:plaintiff][0..254]})
					end
				end
			end
		rescue Exception=>ex
			puts "THERE WAS AN EXCEPTION OF TYPE #{ex.class}, which told us that #{ex.message}"
			puts "Backtrace => #{ex.backtrace}"
    end
	end
end
