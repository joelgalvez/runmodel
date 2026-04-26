require "test_helper"

class AvailableModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @available_model = available_models(:one)
  end

  test "should get index" do
    get available_models_url
    assert_response :success
  end

  test "should get new" do
    get new_available_model_url
    assert_response :success
  end

  test "should create available_model" do
    assert_difference("AvailableModel.count") do
      post available_models_url, params: { available_model: { name: @available_model.name } }
    end

    assert_redirected_to available_model_url(AvailableModel.last)
  end

  test "should show available_model" do
    get available_model_url(@available_model)
    assert_response :success
  end

  test "should get edit" do
    get edit_available_model_url(@available_model)
    assert_response :success
  end

  test "should update available_model" do
    patch available_model_url(@available_model), params: { available_model: { name: @available_model.name } }
    assert_redirected_to available_model_url(@available_model)
  end

  test "should destroy available_model" do
    assert_difference("AvailableModel.count", -1) do
      delete available_model_url(@available_model)
    end

    assert_redirected_to available_models_url
  end
end
