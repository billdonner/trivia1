import SwiftUI
import Observation



// MARK: - ViewModel

@Observable
final class TriviaGameViewModel {
    var challenges: [Challenge] = []
    var currentIndex: Int = 0
    var score: Int = 0
    var showFeedback: Bool = false
    var feedbackText: String = ""
    var gameFinished: Bool = false
    
    // Timer properties
    var timeRemaining: Int = 60  // 60 seconds game duration
    var showTimerWarning: Bool = false
    var timer: Timer?
    
    // Controls whether the user has already answered the current challenge.
    var answerGiven: Bool = false
    
    // Controls whether the hint alert is shown.
    var showHintAlert: Bool = false
    
    func loadChallenges() {
        // Enumerate all JSON files in the main bundle.
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            print("No JSON files found in the main bundle.")
            return
        }
        var loadedChallenges: [Challenge] = []
        let decoder = JSONDecoder()
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let challengesFromFile = try decoder.decode([Challenge].self, from: data)
                loadedChallenges.append(contentsOf: challengesFromFile)
            } catch {
                print("Error loading challenges from \(url.lastPathComponent): \(error)")
            }
        }
        challenges = loadedChallenges.shuffled()  // Randomize challenges on load.
        currentIndex = 0
        score = 0
        gameFinished = false
        answerGiven = false
    }
    
    func startTimer() {
        timer?.invalidate()
        timeRemaining = 60
        showTimerWarning = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timeRemaining -= 1
            self.showTimerWarning = (self.timeRemaining <= 15 && self.timeRemaining > 0)
            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.showHintAlert = false  // Dismiss hint alert if showing.
                self.gameFinished = true
            }
        }
    }
    
    func answerSelected(_ answer: String) {
        guard currentIndex < challenges.count else { return }
        let challenge = challenges[currentIndex]
        if answer == challenge.correct {
            score += 1
            feedbackText = "Correct! \(challenge.explanation)"
        } else {
            feedbackText = "Incorrect. The correct answer is \(challenge.correct). \(challenge.explanation)"
        }
        showFeedback = true
        answerGiven = true
    }
    
    func nextChallenge() {
        answerGiven = false
        showFeedback = false
        currentIndex += 1
        if currentIndex >= challenges.count {
            gameFinished = true
            timer?.invalidate()
        }
    }
    
    func restartGame() {
        loadChallenges()
        startTimer()
    }
    
    func revealHint() {
        showHintAlert = true
    }
}

// MARK: - ContentView

struct ContentView1: View {
    @State var viewModel = TriviaGameViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if !viewModel.gameFinished {
                Text("Time Remaining: \(viewModel.timeRemaining) seconds")
                    .font(.headline)
                    .foregroundColor(viewModel.showTimerWarning ? .red : .black)
            }
            
            if viewModel.challenges.isEmpty {
                Text("Loading challenges...")
            } else if viewModel.gameFinished {
                VStack {
                    Text("Game Over!")
                        .font(.largeTitle)
                    Text("Your score: \(viewModel.score) out of \(viewModel.challenges.count)")
                    Button("Restart Game") {
                        viewModel.restartGame()
                    }
                    .padding()
                }
            } else {
                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.challenges.count)")
                    .font(.headline)
                ScrollView {
                    Text(viewModel.challenges[viewModel.currentIndex].question)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                HStack {
                    Button("Show Hint") {
                        viewModel.revealHint()
                    }
                    .font(.footnote)
                    .padding(8)
                    .disabled(viewModel.answerGiven)
                    
                    Button("Skip Question") {
                        viewModel.nextChallenge()
                    }
                    .font(.footnote)
                    .padding(8)
                    .disabled(viewModel.answerGiven)
                }
                ForEach(viewModel.challenges[viewModel.currentIndex].answers, id: \.self) { answer in
                    Button(action: {
                        viewModel.answerSelected(answer)
                    }) {
                        Text(answer)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                ScrollView {
                    if viewModel.showFeedback {
                        Text(viewModel.feedbackText)
                            .padding()
                    }
                }
                if viewModel.showFeedback {
                    Button("Next Question") {
                        viewModel.nextChallenge()
                    }
                    .padding()
                }
            }
        }
        .padding()
        // Present the hint as a SwiftUI alert.
        .alert("Hint", isPresented: $viewModel.showHintAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if !viewModel.challenges.isEmpty {
                Text(viewModel.challenges[viewModel.currentIndex].hint)
            } else {
                Text("")
            }
        }
        .onAppear {
            viewModel.loadChallenges()
            viewModel.startTimer()
        }
    }
}


