# Destructive cleanup for Phase 9.1 alpha cutover.
# Removes events of retired kinds (player_action, oracle_query) so the
# updated Event.kind enum can validate. No play data is preserved — the
# user has confirmed alpha status with no in-flight sessions.
class CleanPlayEventsForPhase91 < ActiveRecord::Migration[8.1]
  def up
    execute("DELETE FROM events WHERE kind IN ('player_action', 'oracle_query')")
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Phase 9.1 cleanup destroyed events of retired kinds; no rollback possible."
  end
end
