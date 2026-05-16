import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import ChatComposerController from "./controllers/chat_composer_controller"
import DiceChipController from "./controllers/dice_chip_controller"
import DiceFormController from "./controllers/dice_form_controller"
import FlashController from "./controllers/flash_controller"
import NarrationFormController from "./controllers/narration_form_controller"
import SceneLogScrollController from "./controllers/scene_log_scroll_controller"

const application = Application.start()
application.register("chat-composer", ChatComposerController)
application.register("dice-chip", DiceChipController)
application.register("dice-form", DiceFormController)
application.register("flash", FlashController)
application.register("narration-form", NarrationFormController)
application.register("scene-log-scroll", SceneLogScrollController)
