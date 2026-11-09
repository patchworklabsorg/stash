// Stimulus controllers are registered here. Run ./bin/rails stimulus:manifest:update after you add one.
import { application } from "./application"

import ClipboardController from "./clipboard_controller"
application.register("clipboard", ClipboardController)

import DrawerController from "./drawer_controller"
application.register("drawer", DrawerController)

import FlashController from "./flash_controller"
application.register("flash", FlashController)

import PollController from "./poll_controller"
application.register("poll", PollController)

export { application }
