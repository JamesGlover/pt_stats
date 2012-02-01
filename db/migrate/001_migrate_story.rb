class MigrateStory < ActiveRecord::Migration
  
  def self.up

    create_table :stories do |t|
          t.integer :ticket_id
          t.string :name
          t.datetime :created
          t.datetime :started
          t.datetime :finished
          t.datetime :delivered
          t.datetime :accepted
          t.datetime :rejected
          t.string :ticket_type
          t.integer :rejection_count, :default => 0
        end
        add_index :stories, :id
  end

  def self.down
    drop_table :stories
  end
  
end
