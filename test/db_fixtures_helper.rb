# This helper includes utility methods for creating complete objects in the DB during integration tests.
# Ideally we'd expose stable APIs in our web server to create these objects, so our tests don't need to
# interact with the less-stable DB schema directly.
def create_comment(commit, user, created_at, other_options = {})
  Comment.create({
      :user_id => user.id, :commit_id => commit.id, :text => "testing comment. Created at #{created_at}",
      :created_at => created_at, :updated_at => created_at,
      :has_been_emailed => false }.merge(other_options))
end