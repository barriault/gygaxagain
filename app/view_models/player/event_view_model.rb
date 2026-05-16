module Player
  class EventViewModel < ApplicationViewModel
    expose :id, :kind, :occurred_at

    expose :text do
      render_text
    end

    expose :occurred_at_label do
      @record.occurred_at.iso8601
    end

    private

    def render_text
      case @record.kind
      when "narration"             then @record.payload["text"].to_s
      when "pc_declaration"        then @record.payload["text"].to_s
      when "gm_collection_prompt"  then @record.payload["text"].to_s
      when "dice_roll"             then "Rolled #{@record.payload["expression"]} → #{@record.payload["result"]}"
      when "scene_transition"      then @record.payload["reason"].to_s
      else                              ""
      end
    end
  end
end
