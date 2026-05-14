import { Application } from "@hotwired/stimulus"
import FlashController from "./controllers/flash_controller"
import DiceFormController from "./controllers/dice_form_controller"
import OracleFormController from "./controllers/oracle_form_controller"

const application = Application.start()
application.register("flash", FlashController)
application.register("dice-form", DiceFormController)
application.register("oracle-form", OracleFormController)
