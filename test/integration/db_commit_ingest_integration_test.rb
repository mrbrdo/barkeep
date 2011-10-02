require File.expand_path(File.join(File.dirname(__FILE__), "../integration_test_helper.rb"))
require "resque_jobs/db_commit_ingest"
require "resque_jobs/generate_tagged_diffs"

class DbCommitIngestIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup do
    @enqueued_jobs = []
    stub(Resque).enqueue do |*args|
      @enqueued_jobs.push(args)
    end
  end

  should "import commits which are not yet in the database" do
    head = test_repo.head.commit
    Commit.filter(:sha => head.sha).destroy
    DbCommitIngest.perform("test_git_repo", "master")

    commits = Commit.filter(:sha => test_repo.head.commit.sha).all
    assert_equal 1, commits.size
    commit = commits.first
    # Ensure that a user was linked with this commit.
    assert_equal head.author.email, commit.user.email
    assert_equal head.message, commit.message
    # We enqueue a job to pregenerate this commit's highlighted diffs.
    assert_equal [GenerateTaggedDiffs, test_repo.name, commit.sha], @enqueued_jobs.first

    Commit.filter(:sha => head.sha).delete
  end
end