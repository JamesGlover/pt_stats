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
          t.datetime :deleted
          t.string :ticket_type
        end
        add_index :stories, :id
  end

  def self.down
    drop_table :stories
  end
  
end
