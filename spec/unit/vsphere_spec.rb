require 'rspec'
require_relative '../../lib/mkvm'
require_relative '../../lib/vsphere'

describe Vsphere do
  context 'When valid options are given' do
    it 'should not raise exception' do
      options = valid_options
      expect {subject.validate(options)}.to_not raise_exception
    end
  end

  context 'When invalid options are given' do
    context 'When password is invalid' do
      it 'should raise an exception' do
        options = invalid_subnet_options
        expect {subject.validate(options)}.to raise_error(SystemExit)
      end
    end
  end
end

#Helper Methods
def valid_options
  options = {:debug=>false,
   :username=>"Administrator",
   :insecure=>true,
   :make_vm=>true,
   :host=>"vcenter.example.com",
   :dc=>"Primary",
   :cluster=>"Production",
   :ds_regex=>"encrypted",
   :netmask=>"255.255.255.0",
   :dns=>"192.168.1.1, 192.168.1.2",
   :app_env=>"production",
   :domain=>"example.com",
   :power_on=>true,
   :sat_url=>"https://satellite.example.com/rpc/api",
   :sat_username=>"Admin",
   :puppetmaster_url=>"https://puppetmaster.example.com",
   :puppetdb_url=>"https://puppetdb.example.com",
   :puppet_env=>"Production",
   :puppet_cert=>"/path/to/cert.pem",
   :puppet_key=>"/path/to/key.pem",
   :add_uri=>"https://ipam.dev/api/getFreeIP.php?subnet=SUBNET&apiapp=APIAPP&apitoken=APITOKEN&host=HOSTNAME&user=USER",
   :del_uri=>"https://ipam.dev/api/removeHost.php?host=HOSTNAME&apiapp=APIAPP&apitoken=APITOKEN",
   :apiapp=>"ipamip",
   :apitoken=>"inserttoken",
   :shinken_url=>"https://shinken.example.com",
   :dvswitch=>{"dc1"=>"dvswitch1uuid", "dc2"=>"dvswitch2uuid"},
   :network=>{"192.168.20.0"=>{"name"=>"Production", "portgroup"=>"dvportgroup1-number"},
                 "192.168.30.0"=>{"name"=>"DMZ", "portgroup"=>"dvportgroup2-number"}},
   :annotation=>"env-appserver",
   :subnet=>"192.168.20.0",
   :template=>'small',
   :password=>'insertpassword'}

  return options
end

def invalid_subnet_options
  options = valid_options
  options[:subnet] = "derp"
  return options
end