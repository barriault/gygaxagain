import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import FlashController from "./controllers/flash_controller"
import DiceFormController from "./controllers/dice_form_controller"
import NarrationFormController from "./controllers/narration_form_controller"
import SceneLogScrollController from "./controllers/scene_log_scroll_controller"

const application = Application.start()
application.register("flash", FlashController)
application.register("dice-form", DiceFormController)
application.register("narration-form", NarrationFormController)
application.register("scene-log-scroll", SceneLogScrollController)
