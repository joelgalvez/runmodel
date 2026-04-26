class ServersController < ApplicationController
  before_action :set_server, only: %i[ show edit update destroy ]

  # GET /servers or /servers.json
  def index
    @servers = Server.order(created_at: :desc)
  end

  # GET /servers/1 or /servers/1.json
  def show
  end

  # GET /servers/new
  def new
    @server = Server.new
  end

  # GET /servers/1/edit
  def edit
  end

  # POST /servers or /servers.json
  def create
    @server = Server.new(server_params)

    respond_to do |format|
      if @server.save
        format.html { redirect_to @server, notice: "Server was successfully created." }
        format.json { render :show, status: :created, location: @server }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @server.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /servers/1 or /servers/1.json
  def update
    respond_to do |format|
      if @server.update(server_params)
        format.html { redirect_back fallback_location: @server, notice: "Server was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @server }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @server.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /servers/1 or /servers/1.json
  def destroy
    @server.destroy!

    respond_to do |format|
      format.html { redirect_to servers_path, notice: "Server was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_server
      @server = Server.find(params.expect(:id))
    end

    def server_params
      params.expect(server: [ :url, :login, :password ])
    end
end
