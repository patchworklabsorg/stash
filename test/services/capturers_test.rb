require "test_helper"

class CapturersTest < ActiveSupport::TestCase
  test "every error class has a code the captures table accepts" do
    [ Capturers::Timeout, Capturers::TooLarge, Capturers::ToolFailed, Capturers::NotPublic,
      Capturers::NotFound, Capturers::Blocked ].each do |klass|
      assert_includes Capturers::CODES, klass.code, klass.name
      assert_equal klass.code, klass.new("x").code
    end
  end

  test "http_error picks the class from the status" do
    assert_instance_of Capturers::NotPublic, Capturers.http_error(401, "x")
    assert_instance_of Capturers::Blocked, Capturers.http_error(403, "x")
    assert_instance_of Capturers::Blocked, Capturers.http_error(429, "x")
    assert_instance_of Capturers::NotFound, Capturers.http_error(404, "x")
    assert_instance_of Capturers::NotFound, Capturers.http_error("410", "x")
    assert_instance_of Capturers::ToolFailed, Capturers.http_error(500, "x")
    assert_equal 404, Capturers.http_error(404, "x").http_status
    assert_equal "x", Capturers.http_error(404, "x").message
  end

  test "every code has a hint, and an unknown code gets the generic one" do
    Capturers::CODES.each { |code| assert Capturers.hint(code).present?, code }
    assert_equal Capturers.hint("tool_failed"), Capturers.hint("something_else")
  end
end
