package main
import "core:c"
import "core:fmt"
import "core:sys/posix"

import im "lib/odin-imgui"
import "lib/odin-imgui/imgui_impl_glfw"
import "lib/odin-imgui/imgui_impl_opengl3"
import zmq "lib/odin-zeromq"
import gl "vendor:OpenGL"
import "vendor:glfw"

// https://gitlab.com/L-4/odin-imgui/-/blob/main/examples/glfw_opengl3/main.odin?ref_type=heads
// https://gist.github.com/SorenSaket/155afe1ec11a79def63341c588ade329

DISABLE_DOCKING :: #config(DISABLE_DOCKING, false)
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3
GLSL_VERSION :: "#version 150"

SHM_NAME :: "/tmp_vid"
ZEROMQ_ADDR :: "ipc:///tmp/tmp_vid"


main :: proc() {
	assert(cast(bool)glfw.Init(), "Failed to initialize GLFW")
	defer glfw.Terminate()

	// Set Window Hints
	// https://www.glfw.org/docs/latest/window_guide.html#window_hints
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.RESIZABLE, 1)

	window := glfw.CreateWindow(640, 800, "Test", nil, nil)
	assert(window != nil, "Failed to create window")
	defer glfw.DestroyWindow(window)
	glfw.MakeContextCurrent(window)
	glfw.SwapInterval(1) // vsync

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glfw.GetProcAddress(name)
	})

	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}

	when !DISABLE_DOCKING {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := im.GetStyle()
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}

	im.StyleColorsDark()
	assert(imgui_impl_glfw.InitForOpenGL(window, true), "Failed to initialize ImGui GLFW")
	defer imgui_impl_glfw.Shutdown()
	assert(imgui_impl_opengl3.Init(GLSL_VERSION), "Failed to initialize ImGui OpenGL3")
	defer imgui_impl_opengl3.Shutdown()

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		imgui_impl_opengl3.NewFrame()
		imgui_impl_glfw.NewFrame()
		im.NewFrame()

		if im.Begin("Window containing a quit button") {
			if im.Button("quit me!") {
				glfw.SetWindowShouldClose(window, true)
			}
		}
		im.End()

		im.Render()
		display_w, display_h := glfw.GetFramebufferSize(window)
		gl.Viewport(0, 0, display_w, display_h)
		gl.ClearColor(0, 0, 0, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT)
		imgui_impl_opengl3.RenderDrawData(im.GetDrawData())

		when !DISABLE_DOCKING {
			backup_current_window := glfw.GetCurrentContext()
			im.UpdatePlatformWindows()
			im.RenderPlatformWindowsDefault()
			glfw.MakeContextCurrent(backup_current_window)
		}

		glfw.SwapBuffers(window)
	}
}
