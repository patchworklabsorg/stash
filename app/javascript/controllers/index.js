// Stimulus controllers are registered here. Run ./bin/rails stimulus:manifest:update after you add one.
import { application } from "./application"

import DrawerController from "./drawer_controller"
application.register("drawer", DrawerController)

import FlashController from "./flash_controller"
application.register("flash", FlashController)

export { application }
