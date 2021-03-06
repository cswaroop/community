class Api::SettingsController < Api::ApiController
  skip_authorization_check only: :update

  def update
    current_user.update!(settings_params)
    render json: {}
  end

private
  def settings_params
    params.require(:settings).permit(:email_on_mention, :subscribe_on_create, :subscribe_when_mentioned, :subscribe_new_thread_in_subscribed_subforum)
  end
end
