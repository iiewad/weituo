require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index lists accounts with their campus authorizations" do
    get admin_users_path

    assert_response :success
    assert_select "table tbody tr", count: User.count
    assert_select "td", text: /user1/
    assert_select "td", text: /超级管理员/
  end

  test "index renders authorization rows wired for campus and grade filtering" do
    get admin_users_path

    assert_response :success
    assert_select "form[data-controller='user-campuses']", minimum: 1
    assert_select "select[data-user-campuses-target='campuse'] option[data-school-id]"
    assert_select "input[type='checkbox'][name$='[grade_ids][]'][data-school-ids]", minimum: 1
  end

  test "create" do
    assert_difference -> { User.count }, 1 do
      post admin_users_path, params: { user: { name: "new_user", password: "password" } }
    end
    assert_redirected_to admin_users_path
  end

  test "create with campus authorizations" do
    assert_difference -> { User.count }, 1 do
      assert_difference -> { UserCampuse.count }, 1 do
        post admin_users_path, params: { user: {
          name: "authorized_user", password: "password",
          user_campuses_attributes: { "0" => {
            campuse_id: campuses(:campuse_1).id, role: "manager", grade_ids: [ "", "7", "8" ]
          } }
        } }
      end
    end

    user_campuse = User.find_by!(name: "authorized_user").user_campuses.sole
    assert_equal schools(:school_1), user_campuse.school
    assert_equal [ 7, 8 ], user_campuse.grade_ids
    assert_equal "manager", user_campuse.role
  end

  test "create ignores authorization rows without a campus" do
    assert_difference -> { User.count }, 1 do
      assert_no_difference -> { UserCampuse.count } do
        post admin_users_path, params: { user: {
          name: "plain_user", password: "password",
          user_campuses_attributes: { "0" => { campuse_id: "", role: "manager" } }
        } }
      end
    end
  end

  test "update changes the name and password" do
    user = users(:two)

    put admin_user_path(user), params: { user: { name: "改名", password: "newpassword" } }

    assert_redirected_to admin_users_path
    assert_equal "改名", user.reload.name
    assert user.authenticate("newpassword")
  end

  test "update lets the password stay unchanged when blank" do
    user = users(:two)

    put admin_user_path(user), params: { user: { name: "改名", password: "" } }

    assert_redirected_to admin_users_path
    assert user.reload.authenticate("password")
  end

  test "update adds and revokes campus authorizations" do
    user = users(:two)
    other_campus = schools(:school_1).campuses.create!(name: "区2")

    assert_difference -> { user.user_campuses.count }, 1 do
      put admin_user_path(user), params: { user: {
        user_campuses_attributes: { "0" => { campuse_id: other_campus.id, role: "admin", grade_ids: [ "9" ] } }
      } }
    end

    added = user.user_campuses.find_by!(campuse: other_campus)
    assert_equal schools(:school_1).id, added.school_id
    assert_equal [ 9 ], added.grade_ids

    assert_difference -> { user.user_campuses.count }, -1 do
      put admin_user_path(user), params: { user: {
        user_campuses_attributes: { "0" => { id: added.id, _destroy: "1" } }
      } }
    end

    assert_not UserCampuse.exists?(added.id)
  end

  test "cannot grant a campus from another school" do
    other_school = School.create!(name: "其他学校")
    other_campus = other_school.campuses.create!(name: "其他校区")
    user = users(:two)

    assert_no_difference -> { user.user_campuses.count } do
      put admin_user_path(user), params: { user: {
        user_campuses_attributes: { "0" => { campuse_id: other_campus.id, role: "admin" } }
      } }
    end

    assert_redirected_to admin_users_path
    assert_match "其他学校", flash[:alert]
  end

  test "managers cannot manage users" do
    sign_in_as users(:two)

    get admin_users_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end

  test "users routes are limited to the actions the page uses" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/users/new", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/users/1", method: :delete)
    end
  end

  test "create without a password does not create a user" do
    assert_no_difference -> { User.count } do
      post admin_users_path, params: { user: { name: "no_password", password: "" } }
    end

    assert_redirected_to admin_users_path
    assert_match "失败", flash[:alert]
  end
end
