require 'test_helper'

require 'outpost/scouts'

describe "using more complex DSL integration test" do
  before(:each) do
    @server = Server.new
    @server.boot(TestApp)

    while !@server.responsive?
      sleep 0.1
    end
  end

  class ExamplePingAndHttp < Outpost::DSL
    using Outpost::Scouts::Http => 'master http server' do
      options :host => 'localhost', :port => 9595, :path => '/'
      report :up, :response_body => {:match => /Up/}
    end

    using Outpost::Scouts::Ping => 'load balancer' do
      options :host => 'localhost'
      report :up, :response_time => {:less_than => 500}
    end
  end

  class ExampleOneFailingOnePassing < Outpost::DSL
    using Outpost::Scouts::Http => 'master http server' do
      options :host => 'localhost', :port => 9595, :path => '/'
      report :up, :response_body => {:match => /Up/}
    end

    using Outpost::Scouts::Ping => 'load balancer' do
      options :host => 'localhost'
      report :up, :response_time => {:less_than => 0}
    end
  end

  class ExampleAllFailing < Outpost::DSL
    using Outpost::Scouts::Http => 'master http server' do
      options :host => 'localhost', :port => 9595, :path => '/fail'
      report :up, :response_body => {:match => /Up/}
    end

    using Outpost::Scouts::Ping => 'load balancer' do
      options :host => 'localhost'
      report :up, :response_time => {:less_than => -1}
    end
  end

  it "should report up when everything's ok" do
    assert_equal :up, ExamplePingAndHttp.new.run
  end

  it "should report down when at least one scout reports down" do
    assert_equal :down, ExampleOneFailingOnePassing.new.run
  end

  it "should report down when all are down" do
    assert_equal :down, ExampleAllFailing.new.run
  end

  it "should build error message" do
    outpost = ExampleAllFailing.new
    outpost.run

    assert outpost.messages.include?(
      "Outpost::Scouts::Http: 'master http server' is reporting down."
    )

    assert outpost.messages.include?(
      "Outpost::Scouts::Ping: 'load balancer' is reporting down."
    )

  end
end
