# frozen_string_literal: true

class FollowRequest < ApplicationRecord
  include Paginable
  include Streamable

  belongs_to :account
  belongs_to :target_account, class_name: 'Account'

  has_one :notification, as: :activity, dependent: :destroy

  validates :account, :target_account, presence: true
  validates :account_id, uniqueness: { scope: :target_account_id }

  def authorize!
    @verb   = :authorize
    @target = clone.freeze

    account.follow!(target_account)
    MergeWorker.perform_async(target_account.id, account.id)

    destroy!
  end

  def reject!
    @verb   = :reject
    @target = clone.freeze

    destroy!
  end

  def verb
    destroyed? ? (@verb || :delete) : :request_friend
  end

  def target
    if destroyed? && @verb
      @target
    else
      target_account
    end
  end

  def hidden?
    true
  end

  def needs_stream_entry?
    true
  end

  def title
    if destroyed?
      case @verb
      when :authorize
        "#{target_account.acct} authorized #{account.acct}'s request to follow"
      when :reject
        "#{target_account.acct} rejected #{account.acct}'s request to follow"
      else
        "#{account.acct} withdrew the request to follow #{target_account.acct}"
      end
    else
      "#{account.acct} requested to follow #{target_account.acct}"
    end
  end
end