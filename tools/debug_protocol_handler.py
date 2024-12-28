#!/usr/bin/env python3
import sys
import tkinter as tk
from tkinter import scrolledtext

def main():
    root = tk.Tk()
    root.title("Protocol Handler Debugger")
    root.geometry("500x300")

    label = tk.Label(root, text="Received URL Parameters:")
    label.pack(pady=10)

    # Scrollable text box for parameters
    text_area = scrolledtext.ScrolledText(root, wrap=tk.WORD, width=50, height=10)
    text_area.pack(pady=10)

    # Get arguments passed to the script
    params = "\n".join(sys.argv[1:])
    text_area.insert(tk.END, params)

    root.mainloop()

if __name__ == "__main__":
    main()
    
