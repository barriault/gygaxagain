class DiceRollCreator
  def self.call(scene:, pc:, expression:, reason: nil, turn_number:)
    roll = ::Dice::Roll.call(expression)
    scene.events.create!(
      kind: "dice_roll",
      pc: pc,
      turn_number: turn_number,
      payload: {
        "expression" => expression,
        "result"     => roll.total,
        "breakdown"  => roll.breakdown,
        "reason"     => reason
      }.compact
    )
  end
end
