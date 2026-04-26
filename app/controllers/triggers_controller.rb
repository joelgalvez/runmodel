class TriggersController < ApplicationController
  def get_remote_jobs
    GetRemoteJobsJob.perform_later
    redirect_back fallback_location: jobs_path, notice: "GetRemoteJobsJob queued."
  end

  def run_llm
    RunLlmJob.perform_later
    redirect_back fallback_location: jobs_path, notice: "RunLlmJob queued."
  end
end
