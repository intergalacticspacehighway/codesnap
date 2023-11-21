//
//  SettingsView.swift
//  codesnap
//
//  Created by Nishan Bende on 20/11/23.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
  @Published var openAIKey: String {
    didSet {
      UserDefaults.standard.set(openAIKey, forKey: "OpenAIKey")
    }
  }
  @Published var prompt: String{
    didSet {
      UserDefaults.standard.set(openAIKey, forKey: "SavedPrompt")
    }
  }
  
  init() {
    self.openAIKey = UserDefaults.standard.string(forKey: "OpenAIKey") ?? ""
    self.prompt = UserDefaults.standard.string(forKey: "Prompt") ?? "You are a tailwind css expert and an amazing html/css developer who tries to absolutely match the code with the designs. This is an image of a UI component design. Make sure you try to match the design as shown in the image using tailwind css. Replace images and icons in the component with rounded box or rectangles. Please provide output as plain valid HTML only without using backticks or labeling it as HTML or any extra text or any description."
  }
}


struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel
  var body: some View {
    Form {
      VStack(spacing: 0) {
        SecureField("OpenAI Secret Key", text: $viewModel.openAIKey)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding()
        
        VStack(spacing: 4) {
          Text("Prompt")
            .font(.headline)
      
          
          TextEditor(text: $viewModel.prompt)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
        }
        
        
      }
    }
  }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
