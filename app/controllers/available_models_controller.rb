class AvailableModelsController < ApplicationController
  before_action :set_available_model, only: %i[ show edit update destroy ]

  # GET /available_models or /available_models.json
  def index
    @available_models = AvailableModel.all
  end

  # POST /available_models/sync
  def sync
    job = RunLlmJob.new
    models = job.fetch_llama_models
    if models
      job.sync_models_if_changed
      GetRemoteJobsJob.new.push_available_models(models)
      redirect_to available_models_path, notice: "Models pushed to remote servers."
    else
      redirect_to available_models_path, alert: "Failed to fetch models from llama-server."
    end
  end

  # GET /available_models/1 or /available_models/1.json
  def show
  end

  # GET /available_models/new
  def new
    @available_model = AvailableModel.new
  end

  # GET /available_models/1/edit
  def edit
  end

  # POST /available_models or /available_models.json
  def create
    @available_model = AvailableModel.new(available_model_params)

    respond_to do |format|
      if @available_model.save
        format.html { redirect_to @available_model, notice: "Available model was successfully created." }
        format.json { render :show, status: :created, location: @available_model }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @available_model.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /available_models/1 or /available_models/1.json
  def update
    respond_to do |format|
      if @available_model.update(available_model_params)
        format.html { redirect_to @available_model, notice: "Available model was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @available_model }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @available_model.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /available_models/1 or /available_models/1.json
  def destroy
    @available_model.destroy!

    respond_to do |format|
      format.html { redirect_to available_models_path, notice: "Available model was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_available_model
      @available_model = AvailableModel.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def available_model_params
      params.expect(available_model: [ :name ])
    end
end
