Shindo.tests('OpenStack | authenticate', ['openstack']) do
  begin
    @old_mock_value = Excon.defaults[:mock]
    Excon.defaults[:mock] = true
    Excon.stubs.clear

    expires      = Time.now.utc + 600
    token        = Fog::Mock.random_numbers(8).to_s
    tenant_token = Fog::Mock.random_numbers(8).to_s

    body = {
      "access" => {
        "token" => {
          "expires" => expires.iso8601,
          "id"      => token,
          "tenant"  => {
            "enabled"     => true,
            "description" => nil,
            "name"        => "admin",
            "id"          => tenant_token,
          }
        },
        "serviceCatalog" => [{
          "endpoints" => [{
            "adminURL" =>
              "http://example:8774/v2/#{tenant_token}",
              "region" => "RegionOne",
            "internalURL" =>
              "http://example:8774/v2/#{tenant_token}",
            "id" => Fog::Mock.random_numbers(8).to_s,
            "publicURL" =>
             "http://example:8774/v2/#{tenant_token}"
          }],
          "endpoints_links" => [],
          "type" => "compute",
          "name" => "nova"
        },
        { "endpoints" => [{
            "adminURL"    => "http://example:9292",
            "region"      => "RegionOne",
            "internalURL" => "http://example:9292",
            "id"          => Fog::Mock.random_numbers(8).to_s,
            "publicURL"   => "http://example:9292"
          }],
          "endpoints_links" => [],
          "type"            => "image",
          "name"            => "glance"
        }],
        "user" => {
          "username" => "admin",
          "roles_links" => [],
          "id" => Fog::Mock.random_numbers(8).to_s,
          "roles" => [
            { "name" => "admin" },
            { "name" => "KeystoneAdmin" },
            { "name" => "KeystoneServiceAdmin" }
          ],
          "name" => "admin"
        },
        "metadata" => {
          "is_admin" => 0,
          "roles" => [
            Fog::Mock.random_numbers(8).to_s,
            Fog::Mock.random_numbers(8).to_s,
            Fog::Mock.random_numbers(8).to_s,]}}}

    tests("v2") do
      Excon.stub({ :method => 'POST', :path => "/v2.0/tokens" },
                 { :status => 200, :body => Fog::JSON.encode(body) })

      expected = {
        :user                     => body['access']['user'],
        :tenant                   => body['access']['token']['tenant'],
        :identity_public_endpoint => nil,
        :server_management_url    =>
          body['access']['serviceCatalog'].
            first['endpoints'].first['publicURL'],
        :token                    => token,
        :expires                  => expires.iso8601,
        :current_user_id          => body['access']['user']['id'],
        :unscoped_token           => token,
      }

      returns(expected) do
        Fog::OpenStack.authenticate_v2(
          :openstack_auth_uri     => URI('http://example/v2.0/tokens'),
          :openstack_tenant       => 'admin',
          :openstack_service_name => %w[compute])
      end
    end

    tests("v2 missing service") do
      Excon.stub({ :method => 'POST', :path => "/v2.0/tokens" },
                 { :status => 200, :body => Fog::JSON.encode(body) })

      raises(Fog::OpenStack::Errors::NotFound,
             'Could not find service network.  Have compute, image') do
        Fog::OpenStack.authenticate_v2(
          :openstack_auth_uri     => URI('http://example/v2.0/tokens'),
          :openstack_tenant       => 'admin',
          :openstack_service_name => %w[network])
      end
    end
  ensure
    Excon.stubs.clear
    Excon.defaults[:mock] = @old_mock_value
  end
end

