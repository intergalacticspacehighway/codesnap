//
//  AppDelegate.swift
//  codesnap
//
//  Created by Nishan Bende on 18/11/23.
//

import Cocoa
import SwiftUI

enum DragHandle {
  case topLeft, topRight, bottomLeft, bottomRight, none
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
  
  var statusBarItem: NSStatusItem!
  var settingsViewModal = SettingsViewModel()
  var overlayWindow: NSWindow!
  var selectionView: SelectionView!
  var toastWindow: NSWindow!
  var popover: NSPopover!
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    //    statusBarItem.button?.title = "CodeSnap"
    statusBarItem.button?.image = NSImage(named: "menubaricon");
    
    let statusBarMenu = NSMenu(title: "Status Bar Menu")
    statusBarItem.menu = statusBarMenu
    let popoverHeight = 400;
    let popoverWidth = 400;
    
    popover = NSPopover()
    popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
    popover.behavior = .transient
    
    let settingsView = SettingsView(viewModel: settingsViewModal)
    let hostingController = NSHostingController(rootView: settingsView)
    
    
    popover.contentViewController = hostingController
    
    statusBarMenu.addItem(
      withTitle: "Selection",
      action: #selector(showOverlay),
      keyEquivalent: "c"
    )
    
    statusBarMenu.addItem(
      withTitle: "Settings",
      action: #selector(showOpenAIKeyPopover),
      keyEquivalent: "s"
    )
    statusBarMenu.addItem(
      withTitle: "Quit App",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    
    
    let hasAccess = CGPreflightScreenCaptureAccess()
    if !hasAccess {
      print("Requesting screen capture access...")
      CGRequestScreenCaptureAccess()
    }
    
  }
  
  
  @objc func showOpenAIKeyPopover(_ sender: AnyObject?) {
    if let button = statusBarItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }
  
  
  
  @objc func quitApp() {
    NSApplication.shared.terminate(self)
  }
  
  
  
  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }
  
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  @objc func showOverlay() {
    let screenRect = NSScreen.main?.frame ?? NSRect.zero
    
    if (overlayWindow == nil) {
      overlayWindow = NSWindow(contentRect: screenRect, styleMask: .borderless, backing: .buffered, defer: false)
      overlayWindow.backgroundColor = NSColor.clear
      overlayWindow.isOpaque = false
      overlayWindow.hasShadow = false
      overlayWindow.ignoresMouseEvents = false
      overlayWindow.level = .screenSaver
    }
    
    selectionView = SelectionView(frame: screenRect)
    selectionView.onSelectionCompleted =  { base64Image in
      self.overlayWindow.orderOut(nil)
      let openAIKey = self.settingsViewModal.openAIKey;
      self.sendImageToOpenAI(base64Image: base64Image, openApiKey: openAIKey) { result in
        switch result {
        case .success(let data):
          
          guard let data = data else {return}
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(data, forType: .string)
          self.showToast(message: "Content copied to clipboard");
          
          
        case .failure(let error):
          print("Error:", error)
          DispatchQueue.main.async {
            let alert = NSAlert.init()
            alert.messageText = "Something went wrong"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
          }
          
        }
      }
    };
    selectionView.onCancelSelection = {
      self.overlayWindow.orderOut(nil)
    }
    
    overlayWindow.contentView = selectionView
    overlayWindow.makeKeyAndOrderFront(nil)
  }
  
  func showToast(message: String, forDuration duration: TimeInterval = 2.0) {
    DispatchQueue.main.async {
      
      guard let screen = NSScreen.main else { return }
      let screenRect = screen.frame
      
      let toastHeight = 50.0
      let toastWidth = 500.0
      
      if (self.toastWindow == nil) {
        
        self.toastWindow = NSWindow(contentRect: NSRect(x: screenRect.width/2 - toastWidth/2, y: screenRect.height/2 - toastHeight/2, width: toastWidth, height: toastHeight), styleMask: .borderless, backing: .buffered, defer: false)
      }
      
      self.toastWindow.isOpaque = false
      self.toastWindow.backgroundColor = NSColor.black.withAlphaComponent(0.7)
      self.toastWindow.level = .floating
      
      let toastLabel = NSTextField(labelWithString: message)
      toastLabel.frame = NSRect(x: 0, y: toastHeight / 2 - 8, width: toastWidth , height: 16)
      toastLabel.alignment = .center
      toastLabel.textColor = NSColor.white
      
      self.toastWindow.contentView?.addSubview(toastLabel)
      self.toastWindow.makeKeyAndOrderFront(nil)
      
      DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        self.toastWindow.orderOut(nil)
        
      }
    }
  }
  
  
  func sendImageToOpenAI(base64Image: String, openApiKey: String, completion: @escaping (Result<String?, Error>) -> Void) {
    
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(openApiKey)", forHTTPHeaderField: "Authorization")
    let prompt = self.settingsViewModal.prompt
    
    // Construct the request body
    let requestBody: [String: Any] = [
      "model": "gpt-4-vision-preview",
      "messages": [
        [
          "role": "user",
          "content": [
            [
              "type": "text",
              "text": prompt
            ],
            [
              "type": "image_url",
              "image_url": [
                "url": base64Image
              ]
            ]
          ]
        ]
      ],
      "max_tokens": 3000
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
    
    let session = URLSession.shared
    let task = session.dataTask(with: request) { data, response, error in
      if let error = error {
        print("Error:", error)
        completion(.failure(error))
        return
      }
      
      guard let data = data else {
        print("No data received")
        return
      }
      
      do {
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          print(jsonObject)
          let openAIError = jsonObject["error"] as? [String: Any];
          if openAIError != nil {
            let error = NSError(domain: Bundle.main.bundleIdentifier ?? "codesnap", code: 0, userInfo: [NSLocalizedDescriptionKey: openAIError?["message"] as? String ?? "Something went wrong"])
            
            completion(.failure(error))
          } else {
            let choices = jsonObject["choices"] as? [[String: Any]]
            let firstChoice = choices?.first
            let message = firstChoice?["message"] as? [String: Any]
            let content = message?["content"] as? String
            completion(.success(content));
          }
          
          
        }
      } catch {
        completion(.failure(error))
        print("Error parsing JSON:", error)
      }
    }
    
    task.resume()
  }
  
}


class SelectionView: NSView {
  
  private var startPoint: NSPoint?
  private var endPoint: NSPoint?
  public var onSelectionCompleted: ((String) -> Void)?
  
  public var onCancelSelection: (() -> Void)?
  private var isDraggingSelection: Bool = false
  private var dragOffset: NSPoint = NSPoint.zero
  private var dragHandleSize: CGFloat = 10.0
  @objc private let captureButton: NSButton
  @objc private let cancelButton: NSButton
  private let borderSize = 2.0;
  private var currentDragHandle: DragHandle = .none
  
  private func isPoint(_ point: NSPoint, nearTo rectPoint: NSPoint) -> Bool {
    let handleRect = NSRect(x: rectPoint.x - (dragHandleSize + 5.0) / 2,
                            y: rectPoint.y - (dragHandleSize + 5.0) / 2,
                            width: (dragHandleSize + 5.0),
                            height: (dragHandleSize + 5.0))
    return handleRect.contains(point)
  }
  private func handle(at point: NSPoint) -> DragHandle {
    guard let startPoint = startPoint, let endPoint = endPoint else { return .none }
    
    let topLeft = NSPoint(x: min(startPoint.x, endPoint.x), y: max(startPoint.y, endPoint.y))
    let topRight = NSPoint(x: max(startPoint.x, endPoint.x), y: max(startPoint.y, endPoint.y))
    let bottomLeft = NSPoint(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y))
    let bottomRight = NSPoint(x: max(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y))
    
    if isPoint(point, nearTo: topLeft) {
      return .topLeft
    } else if isPoint(point, nearTo: topRight) {
      return .topRight
    } else if isPoint(point, nearTo: bottomLeft) {
      return .bottomLeft
    } else if isPoint(point, nearTo: bottomRight) {
      return .bottomRight
    } else {
      return .none
    }
  }
  
  override init(frame frameRect: NSRect) {
    captureButton = NSButton(frame: .zero)
    cancelButton = NSButton(frame: .zero)
    super.init(frame: frameRect)
    configureButton(captureButton, title: "Capture", action: #selector(captureAction))
    configureButton(cancelButton, title: "Cancel", action: #selector(cancelAction))
    
    
    captureButton.isHidden = true
    cancelButton.isHidden = true
    addSubview(captureButton)
    addSubview(cancelButton)
    
    let trackingArea = NSTrackingArea(rect: frameRect, options: [.mouseMoved, .activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
    addTrackingArea(trackingArea)
  }
  
  private func configureButton(_ button: NSButton, title: String, action: Selector) {
    button.title = title
    button.target = self
    button.action = action
    button.bezelStyle = .rounded
  }
  
  @objc private func captureAction() {
    if let capturedImage = captureScreenArea(),
       let base64String = convertImageToBase64(image: capturedImage) {
      print(base64String)
      onSelectionCompleted?(base64String)
    }
  }
  
  @objc private func cancelAction() {
    onCancelSelection?()
  }
  
  private func resizeImage(_ image: NSImage, to newSize: NSSize) -> NSImage {
    let img = NSImage(size: newSize)
    img.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    img.unlockFocus()
    return img
  }
  
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let start = startPoint, let end = endPoint else {
      startPoint = point
      return
    }
    
    currentDragHandle = handle(at: point)
    
    if currentDragHandle == .none {
      let selectionRect = NSRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(end.x - start.x),
        height: abs(end.y - start.y)
      )
      
      if selectionRect.contains(point) {
        isDraggingSelection = true
        dragOffset = NSPoint(x: point.x - selectionRect.origin.x, y: point.y - selectionRect.origin.y)
      } else {
        startPoint = point
        isDraggingSelection = false
      }
      
    }
    
    captureButton.isHidden = true
    cancelButton.isHidden = true
    
  }
  
  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    
    switch currentDragHandle {
    case .topLeft:
      if let endPoint = endPoint, let startPoint = startPoint {
        self.startPoint = NSPoint(x: point.x, y: point.y)
        self.endPoint = NSPoint(x: max(endPoint.x, startPoint.x), y: min(startPoint.y, endPoint.y))
      }
    case .topRight:
      if let startPoint = startPoint, let endPoint = endPoint {
        self.startPoint = NSPoint(x: min(startPoint.x, endPoint.x), y: point.y)
        self.endPoint = NSPoint(x: point.x, y: min(startPoint.y, endPoint.y))
      }
    case .bottomLeft:
      if let endPoint = endPoint, let startPoint = startPoint {
        self.startPoint = NSPoint(x: point.x, y: max(startPoint.y, endPoint.y))
        self.endPoint = NSPoint(x: max(endPoint.x, startPoint.x), y: point.y)
      }
    case .bottomRight:
      if let startPoint = startPoint, let endPoint = endPoint {
        self.startPoint = NSPoint(x: min(startPoint.x, endPoint.x), y: max(startPoint.y, endPoint.y))
        self.endPoint = NSPoint(x: point.x, y: point.y)
      }
    case .none:
      if isDraggingSelection {
        guard let start = startPoint, let end = endPoint else { return }
        let newOrigin = NSPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        startPoint = newOrigin
        endPoint = NSPoint(x: newOrigin.x + width, y: newOrigin.y + height)
      } else {
        endPoint = point
      }
    }
    
    needsDisplay = true
  }
  
  
  override func mouseUp(with event: NSEvent) {
    isDraggingSelection = false
    dragOffset = NSPoint.zero
    currentDragHandle = .none
    
    
    
    if let start = startPoint, let end = endPoint {
      let selectionRect = NSRect(
        x: min(start.x, end.x),
        y: min(start.y, end.y),
        width: abs(end.x - start.x),
        height: abs(end.y - start.y)
      )
      
      positionButtons(below: selectionRect)
    }
    
    
    captureButton.isHidden = false
    cancelButton.isHidden = false
  }
  
  private func positionButtons(below rect: NSRect) {
    let buttonHeight: CGFloat = 30
    let buttonWidth: CGFloat = 80
    let spacing: CGFloat = 10
    
    captureButton.frame = NSRect(x: rect.minX, y: rect.maxY + spacing, width: buttonWidth, height: buttonHeight)
    cancelButton.frame = NSRect(x: rect.minX + buttonWidth + spacing, y: rect.maxY + spacing, width: buttonWidth, height: buttonHeight)
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let startPoint = startPoint, let endPoint = endPoint else {
      return
    }
    
    let selectionRect = NSRect(
      x: min(startPoint.x, endPoint.x),
      y: min(startPoint.y, endPoint.y),
      width: abs(endPoint.x - startPoint.x),
      height: abs(endPoint.y - startPoint.y)
    )
    
    
    let border = NSBezierPath(rect: selectionRect)
    border.lineWidth = borderSize
    
    let dashPattern: [CGFloat] = [6, 3]
    border.setLineDash(dashPattern, count: 2, phase: 0)
    
    NSColor.systemGray.setStroke()
    
    border.stroke()
    
    drawHandle(at: NSPoint(x: selectionRect.minX - dragHandleSize / 2 + borderSize, y: selectionRect.minY - dragHandleSize / 2 + borderSize)) // bottom-left
    drawHandle(at: NSPoint(x: selectionRect.maxX + dragHandleSize / 2 - borderSize , y: selectionRect.minY - dragHandleSize / 2 + borderSize )) // bottom-right
    drawHandle(at: NSPoint(x: selectionRect.minX - dragHandleSize / 2 + borderSize, y: selectionRect.maxY + dragHandleSize / 2 - borderSize)) // top-left
    drawHandle(at: NSPoint(x: selectionRect.maxX + dragHandleSize / 2 - borderSize, y: selectionRect.maxY + dragHandleSize / 2 - borderSize)) // top-right
    
  }
  
  
  private func captureScreenArea() -> NSImage? {
    guard let startPoint = startPoint, let endPoint = endPoint else {return nil}
    let selectionRect = NSRect(
      x: min(startPoint.x, endPoint.x),
      y: min(startPoint.y, endPoint.y),
      width: abs(endPoint.x - startPoint.x),
      height: abs(endPoint.y - startPoint.y)
    )
    // Inset the selection rectangle to exclude the border
    let adjustedRect = selectionRect.insetBy(dx: borderSize, dy: borderSize)
    
    guard let screen = NSScreen.main else { return nil }
    let screenRect = screen.frame
    let captureRect = NSRect(x: adjustedRect.origin.x,
                             y: screenRect.height - adjustedRect.origin.y - adjustedRect.height,
                             width: adjustedRect.width,
                             height: adjustedRect.height)
    
    guard let cgImage = CGWindowListCreateImage(captureRect, .optionOnScreenOnly, kCGNullWindowID, [.boundsIgnoreFraming, .bestResolution]) else { return nil }
    
    
    let image = NSImage(cgImage: cgImage, size: selectionRect.size)
    return image;
  }
  
  
  private func convertImageToBase64(image: NSImage) -> String? {
    guard let tiffRepresentation = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
          let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
      return nil
    }
    
    return "data:image/png;base64," + imageData.base64EncodedString()
  }
  
  private func drawHandle(at point: NSPoint) {
    let handleRect = NSRect(x: point.x - dragHandleSize / 2, y: point.y - dragHandleSize / 2, width: dragHandleSize, height: dragHandleSize)
    NSColor.systemCyan.setFill()
    let path = NSBezierPath(ovalIn: handleRect)
    path.fill()
  }
}
