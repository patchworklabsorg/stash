require "test_helper"
require "support/fake_weave"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include FakeWeave

  test "sign-in page renders" do
    get sign_in_path

    assert_response :success
    assert_includes response.body, "Sign in to Stash"
  end

  test "the layout links only the built stylesheet" do
    get sign_in_path

    assert_select "link[rel=stylesheet]", count: 1
    assert_select "link[rel=stylesheet][href^=?]", "/assets/tailwind-"
  end

  test "the Weave button submits without Turbo, so the browser follows the redirect to Weave" do
    with_fake_weave do
      get sign_in_path

      assert_select "form[action=?][data-turbo=false]", auth_weave_path
    end
  end

  test "the Weave flow signs a person with a role in" do
    with_fake_weave do
      post auth_weave_path
      assert_response :redirect
      location = URI(response.location)
      assert_equal "weave.test", location.host
      query = Rack::Utils.parse_query(location.query)
      assert_equal "S256", query["code_challenge_method"]

      stub_token_endpoint(id_token: id_token_for(nonce: query["nonce"], roles: %w[archivist]))
      get "/auth/callback", params: { code: "abc", state: query["state"] }
      assert_redirected_to archives_path

      get archives_path
      assert_response :success
      assert_includes response.body, "Weave User"
    end
  end

  test "a wrong state fails the sign-in" do
    with_fake_weave do
      post auth_weave_path
      get "/auth/callback", params: { code: "abc", state: "wrong" }

      assert_redirected_to sign_in_path
      get archives_path
      assert_redirected_to sign_in_path
    end
  end

  test "sign out clears the session" do
    sign_in_as(:viewer)
    delete sign_out_path

    assert_redirected_to sign_in_path
    get archives_path
    assert_redirected_to sign_in_path
  end
end
