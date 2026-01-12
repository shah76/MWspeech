/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    
    @State var speechRecognizer: SpeechRecognizer?
    
    var body: some View {
        ZStack {
            // Black background for letterboxing/pillarboxing
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // Video backdrop
            if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
                GeometryReader { geometry in
                    Image(uiImage: videoFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            }
            
            // Bottom controls layer
            
            VStack {
                Spacer()
                ControlsView(viewModel: viewModel)
            }
            .padding(.all, 24)
            // Timer display area with fixed height
            VStack {
                Spacer()
                if viewModel.activeTimeLimit.isTimeLimited && viewModel.remainingTime > 0 {
                    Text("Streaming ending in \(viewModel.remainingTime.formattedCountdown)")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if speechRecognizer == nil {
                speechRecognizer = SpeechRecognizer(viewModel: viewModel)
            }
            speechRecognizer?.startTranscribing()
            
        }
        .onDisappear {
            Task {
                if viewModel.streamingStatus != .stopped {
                    await viewModel.stopSession()
                }
            }
            speechRecognizer?.stopTranscribing()
        }
        // Show captured photos from DAT SDK in a preview sheet
        .sheet(isPresented: $viewModel.showPhotoPreview) {
            if let photo = viewModel.capturedPhoto {
                PhotoPreviewView(
                    photo: photo,
                    onDismiss: {
                        viewModel.dismissPhotoPreview()
                    }
                )
            }
        }
    }
}

// Extracted controls for clarity
struct ControlsView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    var body: some View {
        AutoScrollingTextView(viewModel: viewModel)
        HStack(spacing: 8) {
            CustomButton(
                title: "Stop streaming",
                style: .destructive,
                isDisabled: false
            ) {
                Task {
                    await viewModel.stopSession()
                }
            }
            
            // Timer button
            CircleButton(
                icon: "timer",
                text: viewModel.activeTimeLimit != .noLimit ? viewModel.activeTimeLimit.displayText : nil
            ) {
                let nextTimeLimit = viewModel.activeTimeLimit.next
                viewModel.setTimeLimit(nextTimeLimit)
            }
            
            // Photo button
            CircleButton(icon: "camera.fill", text: nil) {
                viewModel.capturePhoto()
            }
        }
    }
}


struct AutoScrollingTextView: View {
    @ObservedObject var viewModel: StreamSessionViewModel
    
    private let textID = "dynamicTextID"

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Text(viewModel.transcript)
                            .fixedSize() // Prevents text from wrapping to a new line
                            .id(textID)
                            .padding(.horizontal)
                        Spacer() // Pushes content to the leading edge if there is extra space
                    }
                }
                .onChange(of: viewModel.transcript) { oldValue, newValue in
                    // When the text changes, scroll to the end (trailing edge)
                    withAnimation {
                        proxy.scrollTo(textID, anchor: .trailing)
                    }
                }
            }
            .frame(height: 25) // Give the ScrollView a defined height
        }
    }
}
