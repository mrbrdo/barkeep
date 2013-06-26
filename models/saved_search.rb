# A saved search represents a list of commits, some read and some unread.
#
# Columns:
# - email_commits: true if the user should be emailed when new commits are made which match this search.
# - email_comments: true if the user should be emailed when new comments are made.
class SavedSearch < Sequel::Model
  many_to_one :user

  PAGE_SIZE = 10

  # The list of commits this saved search represents.
  def commits(token = nil, direction = "before", min_commit_date)
    result = MetaRepo.instance.find_commits(
      :repos => repos_list,
      :branches => branches_list,
      :authors => authors_list,
      :paths => paths_list,
      :token => token,
      :direction => direction,
      :commit_filter_proc => self.unapproved_only ?
          self.method(:select_unapproved_commits).to_proc :
          self.method(:select_commits_currently_in_db).to_proc,
      :after => min_commit_date,
      :limit => PAGE_SIZE)
    [result[:commits], result[:tokens]]
  end

  # True if this saved search's results include this commit.
  # NOTE(philc): This ignores the "unapproved_only" option of saved searches, because it's currently
  # being used to compute who to send comment emails to, and those computations should not care if a commit
  # has been approved yet.
  def matches_commit?(commit)
    MetaRepo.instance.search_options_match_commit?(commit.git_repo.name, commit.sha,
        :authors => authors_list,
        :paths => paths_list,
        :branches => branches_list,
        :repos => repos_list)
  end

  # Generates a human readable title based on the search criteria.
  def title
    return "All commits" if [repos, branches, authors, paths, messages].all?(&:nil?)
    if !repos.nil? && [authors, branches, paths, messages].all?(&:nil?)
      return "All commits for the #{comma_separated_list(repos_list)} " +
          "#{english_quantity("repo", repos_list.size)}"
    end

    message = ["Commits"]
    author_list = self.authors_list
    message << "by #{comma_separated_list(map_authors_names(authors_list))}" unless authors_list.empty?
    message << "in #{comma_separated_list(paths_list)}" unless paths_list.empty?
    message << "on #{comma_separated_list(branches_list)}" unless branches_list.empty?
    unless repos_list.empty?
      message << "in the #{comma_separated_list(repos_list)} #{english_quantity("repo", repos_list.size)}"
    end
    message.join(" ")
  end

  def authors_list() (self.authors || "").split(",").map(&:strip) end
  def repos_list() (self.repos || "").split(",").map(&:strip) end

  def paths_list
    return [] unless self.paths && !self.paths.empty?
    JSON.parse(self.paths).map(&:strip)
  rescue []
  end

  def branches_list
    return "" unless self.branches
    self.branches.split(",").map(&:strip)
  end

  def self.create_from_search_string(search_string)
    parts = search_string.split(" ")
  end

  private

  def select_commits_currently_in_db(grit_commits)
    MetaRepo.select_commits_currently_in_db(grit_commits)
  end

  def select_unapproved_commits(grit_commits)
    MetaRepo.select_unapproved_commits(grit_commits)
  end

  def english_quantity(word, quantity) quantity == 1 ? word : word + "s" end

  def comma_separated_list(list)
    case list.size
    when 0 then ""
    when 1 then list[0]
    when 2 then "#{list[0]} and #{list[1]}"
    else "#{list[0..-2].join(", ")}, and #{list[-1]}"
    end
  end

  # use the name of the author if email is entered
  def map_authors_names(authors_list)
    authors_list.map do |author|
      if author =~ /^<.*>$/
        users = User.filter("email=?", author.gsub(/^<|>$/,"")).limit(10).all
        next users[0].name if users.length > 0
      end
      author
    end
  end
end
