#encoding: utf-8
require 'spec/spec_helper'

describe 'Integration:' do
  
  before(:each) { 
    start_slanger_with_mongo 
    cleanup_db
  }

  describe 'applications' do
    it 'can be created with the REST API' do
      response = rest_api_post('/applications.json')
      returned_app = JSON::parse(response.body)

      # Retrieve app in mongo db to check that it actually was created
      mongo_app = get_application(returned_app['id'])
      response.code.should eq('201')
      returned_app['id'].should_not be_nil
      returned_app['key'].should_not be_nil
      returned_app['secret'].should_not be_nil

      mongo_app.should_not be_nil
      mongo_app['_id'].should eq(returned_app['id'])
      mongo_app['key'].should eq(returned_app['key'])
      mongo_app['secret'].should eq(returned_app['secret'])
    end

    it 'can be listed with the REST API' do
      # Create two apps
      rest_api_post('/applications.json')
      rest_api_post('/applications.json')
      # list them
      response = rest_api_get('/applications.json')
      returned_apps = JSON::parse(response.body)

      response.code.should eq('200')
      returned_apps.count.should eq(2)
    end
 
    it 'can be deleted with the REST API' do
      # Create two apps
      rest_api_post('/applications.json')
      rest_api_post('/applications.json')
      # list them
      response = rest_api_get('/applications.json')
      apps_before_delete = JSON::parse(response.body)
      # delete one
      delete_response = rest_api_delete('/applications/' + apps_before_delete[0]['id'].to_s + '.json')
      # list them again
      response = rest_api_get('/applications.json')
      apps_after_delete = JSON::parse(response.body)
 
      delete_response.code.should eq('204')
      apps_before_delete.count.should eq(2)
      apps_after_delete.count.should eq(1)
    end
 
    it 'can change their token on request via the API' do
      # Create an app
      rest_api_post('/applications.json')
      # get it
      response = rest_api_get('/applications.json')
      app_before_change = JSON::parse(response.body)[0]
      # change its token
      change_token_response = rest_api_put('/applications/' + app_before_change['id'].to_s + '/generate_new_token.json')
      app_after_change = JSON::parse(change_token_response.body)
      # get it again
      response = rest_api_get('/applications.json')
      app_listed_after_change = JSON::parse(response.body)[0]
 
      app_before_change['_id'].should eq app_after_change['_id']
      app_before_change['key'].should_not eq app_after_change['key']
      app_before_change['secret'].should_not eq app_after_change['secret']
      app_listed_after_change['_id'].should eq app_after_change['_id']
      app_listed_after_change['key'].should eq app_after_change['key']
      app_listed_after_change['secret'].should eq app_after_change['secret']
    end

    it 'cannot have its key changed via the API' do
      # Create an app
      rest_api_post('/applications.json')
      # get it
      response = rest_api_get('/applications.json')
      app_before_change = JSON::parse(response.body)[0]
      # change its key
      app_with_key_changed = app_before_change.clone()
      app_with_key_changed['key'] = "changedkey"
      change_key_response = rest_api_put('/applications/' + app_before_change['id'].to_s + '.json', app_with_key_changed.to_json)

      # get it again
      response = rest_api_get('/applications.json')
      app_after_change = JSON::parse(response.body)[0]
 
      app_before_change['_id'].should eq app_after_change['_id']
      app_before_change['key'].should eq app_after_change['key']
      app_before_change['secret'].should eq app_after_change['secret']
      change_key_response.code.should eq "403" 
    end

    it 'cannot have its secret changed via the API' do
      # Create an app
      rest_api_post('/applications.json')
      # get it
      response = rest_api_get('/applications.json')
      app_before_change = JSON::parse(response.body)[0]
      # change its secret
      app_with_secret_changed = app_before_change.clone()
      app_with_secret_changed['secret'] = "changedsecret"
      change_secret_response = rest_api_put('/applications/' + app_before_change['id'].to_s + '.json', app_with_secret_changed.to_json)

      # get it again
      response = rest_api_get('/applications.json')
      app_after_change = JSON::parse(response.body)[0]
 
      app_before_change['_id'].should eq app_after_change['_id']
      app_before_change['key'].should eq app_after_change['key']
      app_before_change['secret'].should eq app_after_change['secret']
      change_secret_response.code.should eq "403"
    end

    it 'can have its webhook_url changed via the API' do
      # Create an app
      rest_api_post('/applications.json')
      # get it
      response = rest_api_get('/applications.json')
      app_before_change = JSON::parse(response.body)[0]
      # change its webhook_url
      app_with_webhook_changed = app_before_change.clone()
      app_with_webhook_changed['webhook_url'] = "http://example.com/hook"
      change_webhook_response = rest_api_put('/applications/' + app_before_change['id'].to_s + '.json', app_with_webhook_changed.to_json)

      # get it again
      response = rest_api_get('/applications.json')
      app_after_change = JSON::parse(response.body)[0]
 
      app_before_change['_id'].should eq app_after_change['_id']
      app_before_change['key'].should eq app_after_change['key']
      app_before_change['secret'].should eq app_after_change['secret']
      app_after_change['webhook_url'].should eq "http://example.com/hook"
      change_webhook_response.code.should eq "204"
    end
  end
end
