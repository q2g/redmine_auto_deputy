class UserDeputiesController < ApplicationController

  before_action :check_permission, :get_user, except: [:projects_for_user]
  before_action :get_entry, except: [:index, :set_availabilities, :projects_for_user]

  before_action { prepend_view_path("#{Rails.root}/plugins/redmine_auto_deputy/app/views") }

  def index
    @users = User.with_deputy_permission(:be_deputy).where.not(id: @user.id).status(User::STATUS_ACTIVE)
    @projects = @user.projects_with_have_deputies_permission
    @user_deputies_with_projects    = UserDeputy.with_projects.where(:user_id => @user)
    @user_deputies_without_projects = UserDeputy.without_projects.where(:user_id => @user)
  end

  def create
    @deputy = UserDeputy.new(deputy_attributes)
    if @deputy.save
      flash[:notice] = t('.notice.saved')
    else
      flash[:error] = t('.error.not_saved', errors: @deputy.errors.full_messages.to_sentence)
    end
    redirect_to action: :index, user_id: @deputy.user_id
  end

  def move_up
    @user_deputy.move_higher
    redirect_to action: :index, user_id: @user_deputy.user_id
  end

  def move_down
    @user_deputy.move_lower
    redirect_to action: :index, user_id: @user_deputy.user_id
  end

  def delete
    if @user_deputy.destroy
      flash[:notice] = t('.notice.deleted')
    else
      flash[:error] = t('.error.not_deleted', errors: @user_deputy.errors.full_messages.to_sentence )
    end
    redirect_to action: :index, user_id: @user_deputy.user_id
  end

  def set_availabilities
    if availability_attributes.delete(:delete_availabilities) == "1"
      @user.update_attributes(unavailable_from: nil, unavailable_to: nil)
      flash[:notice] = t('.notice.availabilities_cleared')
    elsif @user.update_attributes(availability_attributes)
      flash[:notice] = t('.notice.saved')
    else
      flash[:error] = t('.error.not_saved', errors: @user.errors.full_messages.to_sentence )
    end

    redirect_to action: :index, user_id: @user.id
  end

  def projects_for_user
    @user = User.find(params[:user_id])
    @projects = @user.projects_with_be_deputy_permission
    render "/user_deputies/project_selector", layout: nil
  end

  def toggle_watch_issues
    @user_deputy.toggle! :auto_watch_project_issues
    render status: 200, text: 'OK'
  end

  def toggle_inheritance
    @user_deputy.toggle! :projects_inherit
    render status: 200, text: 'OK'
  end

  private

  def get_entry
    @user_deputy = UserDeputy.where(id: params[:id]).first
  end

  def deputy_attributes
    params.require(:user_deputy).permit(:deputy_id, :project_id).merge(user_id: @user.id)
  end

  def availability_attributes
    permitted = [:unavailable_from, :unavailable_to, :delete_availabilities]
    @availability_attributes ||= params.require(:user_availability).permit(*permitted)
  end

  def check_permission
    if User.current.allowed_to_globally?(:have_deputies) || User.current.allowed_to_globally?(:edit_deputies)
      return true
    else
      flash[:error] = t('user_deputies.permission_denied')
      redirect_to "/"
    end
  end

  def get_user
    if User.current.allowed_to_globally?(:edit_deputies) && params[:user_id]
      @user = User.find(params[:user_id])
    else
      @user = User.current
    end
  end

end
