import subprocess
import time
import os
try:
    from PIL import ImageGrab
    import pyautogui
except ImportError:
    subprocess.check_call(["pip", "install", "pillow", "pyautogui"])
    from PIL import ImageGrab
    import pyautogui

def main():
    print("Launching Godot...")
    godot_path = r"C:\Users\88698\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
    
    # Launch godot windowed, directly to level_1.tscn
    process = subprocess.Popen([godot_path, "res://scenes/level/level_1.tscn"], cwd=r"d:\2026-06-04")
    
    print("Waiting for game to load...")
    time.sleep(4) 
    
    print("Taking screenshot of game start...")
    img2 = ImageGrab.grab()
    img2.save(r"d:\2026-06-04\vlm_frame_start.png")
    
    print("Simulating gameplay...")
    pyautogui.keyDown('right')
    time.sleep(0.5)
    pyautogui.keyUp('right')
    time.sleep(0.1)
    
    # Attack the boss
    pyautogui.press('x')
    time.sleep(0.1)
    
    img3 = ImageGrab.grab()
    img3.save(r"d:\2026-06-04\vlm_frame_play.png")
    
    print("Closing Godot...")
    process.terminate()

if __name__ == "__main__":
    main()
