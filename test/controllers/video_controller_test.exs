defmodule Rumbl.VideoControllerTest do
  use Rumbl.ConnCase
  alias Rumbl.Video

  @valid_attrs %{url: "http://youtu.be", title: "vid", description: "a vid"}
  @invalid_attrs %{title: "invalid"}


  setup config do
    if username = config[:login_as] do
      user = insert_user(username: username)
      conn = assign(conn(), :current_user, user)
      {:ok, conn: conn, user: user}
    else
      {:ok, conn: conn}
    end
  end

  test "require user authentication on all actions", %{conn: conn} do
    Enum.each([
      get(conn, video_path(conn, :index)),
      get(conn, video_path(conn, :show, "123")),
      get(conn, video_path(conn, :edit, "123")),
      put(conn, video_path(conn, :update, "123", %{})),
      post(conn, video_path(conn, :create, %{})),
      delete(conn, video_path(conn, :delete, "123")),
    ], fn conn ->
      assert html_response(conn, 302)
      assert conn.halted
    end)
  end

  @tag login_as: "max"
  test "lists all user's videos on index", %{conn: conn, user: user} do
    user_video = insert_video(user, title: "funny cats")
    other_video = insert_video(insert_user(username: "other"), title: "another video")

    conn = get conn, video_path(conn, :index)
    assert html_response(conn, 200) =~ ~r/Listing videos/
    assert String.contains?(conn.resp_body, user_video.title)
    refute String.contains?(conn.resp_body, other_video.title)
  end

  @tag login_as: "max"
  test "creates user video and redirects", %{conn: conn, user: user} do
    conn = post conn, video_path(conn, :create), video: @valid_attrs
    assert redirected_to(conn) == video_path(conn, :index)
    assert Repo.get_by!(Video, @valid_attrs).user_id == user.id
  end

  @tag login_as: "max"
  test "does not create video and renders errors when invalid", %{conn: conn, user: _user} do
    count_before = video_count(Video)
    conn = post conn, video_path(conn, :create), video: @invalid_attrs
    assert html_response(conn, 200) =~ ~r/check the errors/
    assert video_count(Video) == count_before
  end

  @tag login_as: "max"
  test "authorizes actions against access by other users", %{conn: conn, user: user} do
    video = insert_video(user, @valid_attrs)
    non_owner = insert_user(username: "sneaky")
    conn = assign(conn, :current_user, non_owner)

    assert_raise Ecto.NoResultsError, fn ->
      get(conn, video_path(conn, :show, video))
    end
    assert_raise Ecto.NoResultsError, fn ->
      get(conn, video_path(conn, :edit, video))
    end
    assert_raise Ecto.NoResultsError, fn ->
      put(conn, video_path(conn, :update, video, video: @valid_attrs))
    end
    assert_raise Ecto.NoResultsError, fn ->
      delete(conn, video_path(conn, :delete, video))
    end
  end

  defp video_count(query), do: Repo.one(from v in query, select: count(v.id))

end
