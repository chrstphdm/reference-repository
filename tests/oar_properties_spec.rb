require 'rspec'
require 'webmock/rspec'

$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))
require 'refrepo'

WebMock.disable_net_connect!(allow_localhost: true)

conf = RefRepo::Utils.get_api_config


def load_stub_file_content(stub_filename)
  if not File.exist?("stub_oar_properties/#{stub_filename}")
    raise("Cannot find #{stub_filename} in 'stub_oar_properties/'")
  end
  file = File.open("stub_oar_properties/#{stub_filename}", "r")
  lines = IO.read(file)
  file.close()
  return lines
end

describe 'Oar properties generator' do

  context 'Empty OAR server' do
    before do
      stubbed_api_response = load_stub_file_content("fakesite_from_scratch_do_diff-1.json")
      stub_request(:get, conf["uri"]).
          with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
          to_return(status: 200, body: stubbed_api_response, headers: {})
    end

    it 'should generate correctly' do

      uri = URI(conf["uri"])

      response = Net::HTTP.get(uri)

      expect(response).to be_an_instance_of(String)
    end
  end

  context 'OAR server with data' do
    before do
      stubbed_api_response = load_stub_file_content("fakesite_from_scratch_do_update-1.json")
      stub_request(:get, conf["uri"]).
          with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
          to_return(status: 200, body: stubbed_api_response, headers: {})
    end

    it 'should generate correctly' do

      uri = URI(conf["uri"])

      response = Net::HTTP.get(uri)

      expect(response).to be_an_instance_of(String)
    end
  end
end