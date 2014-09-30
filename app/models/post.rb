class Post < ActiveRecord::Base
  include Searchable

  belongs_to :thread, class_name: "DiscussionThread"
  belongs_to :author, class_name: "User"
  has_and_belongs_to_many :broadcast_groups, class_name: "Group"
  has_many :mentions, class_name: "Notifications::Mention", dependent: :destroy

  validates :body, :author, :thread, presence: {allow_blank: false}

  before_create :add_and_increment_post_number

  def add_and_increment_post_number
    DistributedLock.new("thread_#{thread.id}").synchronize do
      next_post_number = thread.highest_post_number + 1
      self.post_number = next_post_number
      thread.update(highest_post_number: next_post_number)
    end
  end

  def required_roles
    thread.subforum.required_roles
  end

  def mark_as_visited(user)
    thread.mark_post_as_visited(user, self)
  end

  def message_id
    format_message_id(thread_id, post_number)
  end

  def previous_message_id
    if post_number > 1
      format_message_id(thread_id, post_number-1)
    end
  end

  def to_search_mapping
    {
      index: {
        _id: id,
        data: {
          body: body,
          author: author.name,
          author_id: author.id,
          author_hacker_school_id: author.hacker_school_id,
          author_email: author.email,
          thread: thread.title,
          thread_id: thread.id,
          thread_slug: thread.slug,
          post_number: post_number,
          subforum: thread.subforum.name,
          subforum_id: thread.subforum.id,
          subforum_slug: thread.subforum.slug,
          subforum_group: thread.subforum.subforum_group.name,
          subforum_group_id: thread.subforum.subforum_group.id,
          ui_color: thread.subforum.ui_color
        }
      }
    }
  end

  def self.query_dsl(query)
    query_without_filters = self.strip_filters(query)

    # match query for exact matches, terms
    exact_match_query = {
      multi_match: {
        query: query,
        boost: 100,
        fields: [:thread_title, :body]
      }
    }

    # match query for phrase prefixes
    phrase_match_query = {
      multi_match: {
        query: query,
        boost: 10,
        fields: [:thread_title, :body],
        type: :phrase_prefix
      }
    }

    # filtered query for filters
    filters = self.filters(query)
    filtered_query = nil
    unless filters.blank?
      clauses = Array.new
      filters.each do |key, value|
        clauses.push({ term: { key => value } })
      end

      filtered_query = { filtered: { filter: { bool: { must: clauses } } } }
    end

    # Combine exact match and prefix queries
    query_dsl = {
      bool: {
        should: [exact_match_query, phrase_match_query]
      }
    }

    # Add filtered query as a must only when its available
    query_dsl[:bool][:must] = filtered_query unless filtered_query.blank?

    return query_dsl
  end

  def self.highlight_fields
    {
      fields: {
        thread_title: {},
        body: {}
      }
    }
  end

  def self.allowed_filter_fields
    return ["thread", "subforum", "subforum_group", "author"]
  end

private
  def format_message_id(thread_id, post_number)
    "<thread-#{thread_id}/post-#{post_number}@community.hackerschool.com>"
  end
end
