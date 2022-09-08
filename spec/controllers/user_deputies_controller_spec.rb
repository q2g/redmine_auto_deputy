require "spec_helper"
RSpec.describe UserDeputiesController, type: :controller do

  let(:current_user) { create(:user) }
  let(:user_deputy) { create(:user_deputy, user_id: current_user.id) }

  before { allow(User).to receive(:current).and_return(current_user) }

  describe 'before_action' do
    let(:filter) { described_class._process_action_callbacks.select {|c| c.filter == :get_entry }.first }
    specify ':get_entry, except: [:index, :set_availabilities]' do
      expect(filter.kind).to eq(:before)
      expect(filter.instance_variable_get('@unless')).to eq(["action_name == 'index' || action_name == 'set_availabilities' || action_name == 'projects_for_user'"])
    end
  end

  describe '#index' do

    context 'user is allowed' do
      let(:projects) { double }

      before do
        expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
        expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(false)
        expect_any_instance_of(User).to receive(:projects_with_have_deputies_permission).and_return(projects)
        expect(RedmineAutoDeputy::UserDeputyExtension).to receive(:roles_for).with(:be_deputy).and_return([double(id: 1), double(id: 2)])
      end

      specify do
        get :index

        expect(assigns[:users].to_sql).to eq("SELECT users.* FROM users INNER JOIN members ON members.user_id = users.id INNER JOIN member_roles ON member_roles.member_id = members.id INNER JOIN roles ON roles.id = member_roles.role_id WHERE users.type IN ('User', 'AnonymousUser') AND member_roles.role_id IN (1, 2) AND (users.id != #{current_user.id}) AND users.status = #{User::STATUS_ACTIVE} GROUP BY users.id")
        expect(assigns[:user]).to eq(current_user)
        expect(assigns[:projects]).to eq(projects)
        expect(assigns[:user_deputies_with_projects].to_sql).to eq("SELECT user_deputies.* FROM user_deputies INNER JOIN projects ON projects.id = user_deputies.project_id WHERE (user_deputies.project_id IS NOT NULL) AND user_deputies.user_id = #{current_user.id}  ORDER BY projects.name ASC, user_deputies.prio ASC")
        expect(assigns[:user_deputies_without_projects].to_sql).to eq("SELECT user_deputies.* FROM user_deputies WHERE user_deputies.project_id IS NULL AND user_deputies.user_id = #{current_user.id}  ORDER BY user_deputies.prio ASC")
      end
    end

    context 'user is not allowed' do
      before do
        expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(false)
        expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(false)
      end

      specify do
        get :index
        expect(flash[:error]).to eq(I18n.t('user_deputies.permission_denied'))
        expect(response).to redirect_to("/")
      end
    end

    context 'admin selects other user' do
      let(:admin_user)  { create(:user) }

      before do
        allow(User).to receive(:current).and_return(admin_user)
        expect(admin_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(false)
        expect(admin_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(true).exactly(2).times
      end

      specify do
        get :index, user_id: current_user.id
        expect(assigns[:user]).to eq(current_user)
      end
    end
  end

  describe '#create' do

    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(false)
    end

    context 'successful' do
      specify do
        post :create, user_deputy: { project_id: 1, deputy_id: 1 }

        expect(flash[:notice]).to eq(I18n.t('user_deputies.create.notice.saved'))
        expect(assigns[:deputy].user_id).to eq(current_user.id)
        expect(assigns[:deputy].project_id).to eq(1)
        expect(assigns[:deputy].deputy_id).to eq(1)

        expect(response).to redirect_to(user_deputies_path(user_id: assigns[:deputy].user_id))
      end
    end

    context 'not successful' do
      specify do
        post :create, user_deputy: { project_id: 1 }

        expect(flash[:error]).to eq(I18n.t('user_deputies.create.error.not_saved', errors: assigns[:deputy].errors.full_messages.to_sentence))

        expect(response).to redirect_to(user_deputies_path(user_id: assigns[:deputy].user_id))
      end
    end
  end

  describe '#move_up/#move_down' do

    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(false)
    end

    context 'move_up' do
      before { expect_any_instance_of(UserDeputy).to receive(:move_higher).exactly(1).times }
      specify do
        get :move_up, id: user_deputy.id
        expect(response).to redirect_to(user_deputies_path(user_id: user_deputy.user_id))
      end
    end

    context 'move_down' do
      before { expect_any_instance_of(UserDeputy).to receive(:move_lower).exactly(1).times }
      specify do
        get :move_down, id: user_deputy.id
        expect(response).to redirect_to(user_deputies_path(user_id: user_deputy.user_id))
      end
    end
  end

  describe '#delete' do

    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(false)
    end

    context 'successful' do
      before {  expect_any_instance_of(UserDeputy).to receive(:destroy).and_return(true) }

      specify do
        get :delete, id: user_deputy.id

        expect(flash[:notice]).to eq(I18n.t('user_deputies.delete.notice.deleted'))
        expect(response).to redirect_to(user_deputies_path(user_id: user_deputy.user_id))
      end
    end

    context 'not successful' do
      before {  expect_any_instance_of(UserDeputy).to receive(:destroy).and_return(false) }

      specify do
        get :delete, id: user_deputy.id

        expect(flash[:error]).to eq(I18n.t('user_deputies.delete.error.not_deleted', errors: assigns[:user_deputy].errors.full_messages.to_sentence))
        expect(response).to redirect_to(user_deputies_path(user_id: user_deputy.user_id))
      end
    end
  end

  describe '#set_availabilities' do

    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(true)
    end

    context 'delete availabilities' do
      before do
        expect(current_user).to receive(:update_attributes).with(unavailable_from: nil, unavailable_to: nil).and_call_original
      end

      specify do
        post :set_availabilities, user_availability: { delete_availabilities: "1" }
        expect(flash[:notice]).to eq I18n.t('user_deputies.set_availabilities.notice.availabilities_cleared')
        expect(response).to redirect_to(user_deputies_path(user_id: current_user.id))
      end
    end

    context 'update availabilities' do
      let(:other_user)  { create(:user) }

      specify do
        post :set_availabilities, user_id: other_user.id, user_availability: { delete_availabilities: "0", unavailable_from: '01.01.2017', unavailable_to: '01.01.2018' }
        expect(assigns[:user]).to eq(other_user)
        expect(assigns[:user].reload.unavailable_from).to eq(Date.new(2017,1,1))
        expect(assigns[:user].reload.unavailable_to).to eq(Date.new(2018,1,1))
        expect(flash[:notice]).to eq I18n.t('user_deputies.set_availabilities.notice.saved')
        expect(response).to redirect_to(user_deputies_path(user_id: other_user.id))
      end
    end

    context 'fail to update availabilities' do
      before do
        expect(current_user).to receive(:update_attributes).with(unavailable_from: '01.01.2016', unavailable_to: '01.02.2016').and_call_original
      end

      specify do
        post :set_availabilities, user_availability: { delete_availabilities: "0", unavailable_from: '01.01.2016', unavailable_to: '01.02.2016' }
        expect(flash[:error]).to eq(I18n.t('user_deputies.set_availabilities.error.not_saved', errors: assigns[:user].errors.full_messages.to_sentence))
        expect(response).to redirect_to(user_deputies_path(user_id: current_user.id))
      end
    end
  end

  describe '#projects_for_user' do
    let(:projects) { [double(:project, id: 1, name: 'Project')] }

    before do
      expect_any_instance_of(User).to receive(:projects_with_be_deputy_permission).and_return(projects)
    end

    specify do
      get :projects_for_user, user_id: current_user.id
      expect(assigns[:user]).to eq(current_user)
      expect(assigns[:projects]).to eq(projects)
    end
  end

  describe '#toggle_watch_issues' do
    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect_any_instance_of(UserDeputy).to receive(:toggle!).with(:auto_watch_project_issues)
    end
    specify do
      post :toggle_watch_issues, id: user_deputy.id
      expect(response).to be_success
    end
  end

  describe '#toggle_inheritance' do
    before do
      expect(current_user).to receive(:allowed_to_globally?).with(:edit_deputies).and_return(true)
      expect(current_user).to receive(:allowed_to_globally?).with(:have_deputies).and_return(true)
      expect_any_instance_of(UserDeputy).to receive(:toggle!).with(:projects_inherit)
    end
    specify do
      post :toggle_inheritance, id: user_deputy.id
      expect(response).to be_success
    end
  end

  after do
    UserDeputy.delete_all
  end

end
