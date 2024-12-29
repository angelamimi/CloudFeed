//
//  ControlsView.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 9/7/24.
//  Copyright © 2024 Angela Jarosz. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

@MainActor
protocol ControlsDelegate: AnyObject {
    
    func beganTracking()
    func timeChanged(time: Float)
    func volumeChanged(volume: Float)
    
    func volumeButtonTapped()
    func playButtonTapped()
    func fullScreenButtonTapped()
    func tapped()
    
    func captionsSelected(subtitleIndex: Int32)
}

class ControlsView: UIView {
    
    @IBOutlet weak var volumeView: UIVisualEffectView!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var volumeButton: UIButton!
    @IBOutlet weak var volumeTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var captionsButton: UIButton!
    @IBOutlet weak var skipBackButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var skipForwardButton: UIButton!
    @IBOutlet weak var fullScreenButton: UIButton!
    
    weak var delegate: ControlsDelegate?
    
    private var volume: Int = 100 // 0% for mute, 100% for full volume
    private var isPlaying: Bool = false
    private var length: Double = 0
    private let skipSeconds: Int32 = 10
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    private func commonInit() {
        
        guard let view = loadViewFromNib() else { return }
        
        view.frame = bounds
        
        addSubview(view)
        
        setPlaying(playing: false)
        initControls()
    }
    
    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: "ControlsView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    func reset() {
        setPosition(position: 0)
        setTime(time: "00:00")
        setRemainingTime(time: "00:00")
        setPlaying(playing: false)
        
        disableSeek()
        disableCaptions()
    }
    
    func getVolume() -> Float {
        return volumeSlider.value
    }
    
    func enableSeek() {
        setSeekIsEnabled(enabled: true)
    }
    
    func disableSeek() {
        setSeekIsEnabled(enabled: false)
    }
    
    func enable() {
        setIsEnabled(enabled: true)
    }
    
    func disable() {
        setIsEnabled(enabled: false)
    }
    
    func disableCaptions() {
        captionsButton.isEnabled = false
    }
    
    func setMediaLength(length: Double) {
        self.length = length
        
        skipBackButton.isEnabled = true
        skipForwardButton.isEnabled = true
    }
    
    func setPosition(position: Float) {
        if position >= timeSlider.minimumValue && position <= timeSlider.maximumValue {
            timeSlider.setValue(position, animated: true)
        }
    }
    
    func setTime(time: String) {
        timeLabel.text = time
    }
    
    func setRemainingTime(time: String) {
        totalTimeLabel.text = time
    }
    
    func setPlaying(playing: Bool) {
        
        isPlaying = playing

        if playing {
            playButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        } else {
            playButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        }
    }
    
    func setVolume(_ value: Float) {
        
        guard value >= volumeSlider.minimumValue && value <= volumeSlider.maximumValue else { return }
        
        volumeSlider.value = value
    }
    
    func selectCaption(currentSubtitleIndex: Int32) {

        guard let menu = captionsButton.menu else { return }

        for case let option as UIAction in menu.children {
            if option.identifier == UIAction.Identifier(String(currentSubtitleIndex)) {
                option.state = .on
            } else {
                option.state = .off
            }
        }
    }
    
    func initCaptionsMenu(currentSubtitleIndex: Int32?, subtitleIndexes: [Any], subtitleNames: [Any]) {
        
        guard captionsButton.menu == nil else { return }
        
        if subtitleNames.count == 0 {
            captionsButton.isEnabled = false
            return
        }
        
        var menuChildren: [UIMenuElement] = []
        
        for index in 0...subtitleNames.count - 1 {
            
            guard let captionTitle = subtitleNames[index] as? String, let captionIndex = subtitleIndexes[index] as? Int32 else {
                captionsButton.isEnabled = false
                return
            }
            
            let action = UIAction(title: captionTitle, identifier: UIAction.Identifier(rawValue: String(captionIndex))) { [weak self] _ in
                self?.delegate?.captionsSelected(subtitleIndex: captionIndex)
            }
            
            if currentSubtitleIndex != nil && captionIndex == currentSubtitleIndex {
                action.state = .on
            }
            
            menuChildren.append(action)
        }
        
        captionsButton.menu = UIMenu(options: .displayInline, children: menuChildren)

        captionsButton.showsMenuAsPrimaryAction = true
        captionsButton.changesSelectionAsPrimaryAction = false
        captionsButton.isEnabled = true
    }
    
    @objc private func volumeChanged() {

        delegate?.volumeChanged(volume: volumeSlider.value)
        
        if volumeSlider.value == 0 {
            setVolumeButton(mute: true)
        } else {
            setVolumeButton(mute: false)
        }
    }
    
    @objc private func timeChanged() {
        delegate?.timeChanged(time: timeSlider.value)
    }
    
    @objc private func volumeButtonTapped() {

        delegate?.volumeButtonTapped()
        
        if volume == 0 {
            volume = 100
            setVolumeButton(mute: false)
            volumeSlider.value = 100
        } else {
            volume = 0
            setVolumeButton(mute: true)
            volumeSlider.value = 0
        }
    }
    
    @objc private func skipBackButtonTapped() {
        skip(forward: false)
    }
    
    @objc private func playButtonTapped() {
        
        delegate?.playButtonTapped()
        
        if isPlaying {
            setPlaying(playing: false)
        } else {
            setPlaying(playing: true)
        }
    }
    
    @objc private func skipForwardButtonTapped() {
        skip(forward: true)
    }
    
    @objc private func fullScreenButtonTapped() {
        delegate?.fullScreenButtonTapped()
    }
    
    @objc private func volumeButtonDown() {
        highlightButton(button: volumeButton)
    }
    
    @objc private func fullScreenButtonDown() {
        highlightButton(button: fullScreenButton)
    }
    
    @objc private func skipBackButtonDown() {
        highlightButton(button: skipBackButton)
    }
    
    @objc private func skipForwardButtonDown() {
        highlightButton(button: skipForwardButton)
    }
    
    @objc private func playButtonDown() {
        highlightButton(button: playButton)
    }
    
    @objc private func timeSliderPan(panGesture: UIPanGestureRecognizer) {
        
        switch panGesture.state {
        case .began:
            delegate?.beganTracking() 
        case .changed:

            let location = panGesture.location(in: timeSlider)
            var value = Float.init(location.x / timeSlider.frame.width)
            
            if value < timeSlider.minimumValue {
                value = 0
            } else if value > timeSlider.maximumValue {
                value = timeSlider.maximumValue
            }
            
            timeSlider.value = value
            
            if length > 0 {
                setTimeLabelFromPosition(value)
            }
            
        case .ended,
             .cancelled:
            delegate?.timeChanged(time: timeSlider.value)
        default:
            break
        }
    }
    
    @objc private func timeSliderTapped(tapGesture: UITapGestureRecognizer) {
        
        let location = tapGesture.location(in: timeSlider)
        let value = Float.init(location.x / timeSlider.frame.width)
        
        if value >= timeSlider.minimumValue && value <= timeSlider.maximumValue {
            timeSlider.value = value
            delegate?.timeChanged(time: value)
            setTimeLabelFromPosition(value)
        }
    }
    
    @objc private func volumeSliderPan(panGesture: UIPanGestureRecognizer) {
        
        switch panGesture.state {
        case .began:
            break
        case .changed:

            let location = panGesture.location(in: volumeView)
            var value = Float.init(location.x / volumeSlider.frame.width) * 100
            
            if value < volumeSlider.minimumValue {
                value = 0
            } else if value > volumeSlider.maximumValue {
                value = volumeSlider.maximumValue
            }
            
            volumeSlider.value = value
            
        case .ended,
             .cancelled:
            volumeChanged()
        default:
            break
        }
    }
    
    @objc private func volumeSliderTapped(tapGesture: UITapGestureRecognizer) {
        
        let location = tapGesture.location(in: volumeView)
        let value = Float.init(location.x / volumeSlider.frame.width) * 100
        
        if value >= volumeSlider.minimumValue && value <= volumeSlider.maximumValue {
            volumeSlider.value = value
            volumeChanged()
        }
    }
    
    @objc private func tapped(tapGesture: UITapGestureRecognizer) {
        
        let location = tapGesture.location(in: tapGesture.view)
        
        if controlsView.frame.contains(location) == false {
            delegate?.tapped()
        }
    }
    
    private func skip(forward: Bool) {
        
        guard length > 0 else { return }
        
        let mediaLength = length / 1_000
        let currentTime = Double.init(timeSlider.value) * mediaLength
        var newTime: Double
        
        if forward {
            newTime = currentTime + Double.init(skipSeconds)
        } else {
            newTime = currentTime - Double.init(skipSeconds)
        }
        
        var newPosition = Float.init(newTime / mediaLength)

        if newPosition < timeSlider.minimumValue {
            newPosition = 0
        } else if newPosition > timeSlider.maximumValue {
            newPosition = 1
        }
        
        timeSlider.value = newPosition
        setTimeLabelFromPosition(newPosition)
        
        delegate?.timeChanged(time: newPosition)
    }
    
    private func setTimeLabelFromPosition(_ position: Float) {
        
        let lengthSeconds = length / 1_000
        let timeValue = lengthSeconds * Double.init(position)
        let remainingValue = lengthSeconds - timeValue
        let formatter = DateComponentsFormatter()
       
        formatter.allowedUnits = timeValue >= (60 * 60) ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        
        timeLabel.text = formatter.string(from: TimeInterval(timeValue))!
        totalTimeLabel.text = "-\(formatter.string(from: TimeInterval(remainingValue))!)"
    }
    
    private func setVolumeButton(mute: Bool) {
        if mute {
            volumeButton.setImage(UIImage(systemName: "speaker.slash"), for: .normal)
        } else {
            volumeButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        }
    }
    
    private func setIsEnabled(enabled: Bool) {
        volumeButton.isEnabled = enabled
        volumeSlider.isEnabled = enabled
        timeSlider.isEnabled = enabled
        captionsButton.isEnabled = enabled
        playButton.isEnabled = enabled
        fullScreenButton.isEnabled = enabled
        timeLabel.isEnabled = enabled
        totalTimeLabel.isEnabled = enabled
        skipBackButton.isEnabled = enabled
        skipForwardButton.isEnabled = enabled
    }
    
    private func setSeekIsEnabled(enabled: Bool) {
        timeSlider.isEnabled = enabled
        skipBackButton.isEnabled = enabled
        skipForwardButton.isEnabled = enabled
    }
    
    private func highlightButton(button: UIButton) {
        button.tintColor = .secondaryLabel
        UIView.animate(withDuration: 0.4, animations: {
            button.tintColor = .label
        })
    }
    
    private func initControls() {
        
        controlsView.minimumContentSizeCategory = .large
        controlsView.maximumContentSizeCategory = .extraExtraExtraLarge
        
        volumeView.clipsToBounds = true
        volumeView.layer.cornerRadius = 8
        
        controlsView.clipsToBounds = true
        controlsView.layer.cornerRadius = 8
        
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        timeSlider.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        
        volumeButton.addTarget(self, action: #selector(volumeButtonTapped), for: .touchUpInside)
        skipBackButton.addTarget(self, action: #selector(skipBackButtonTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        skipForwardButton.addTarget(self, action: #selector(skipForwardButtonTapped), for: .touchUpInside)
        fullScreenButton.addTarget(self, action: #selector(fullScreenButtonTapped), for: .touchUpInside)
        
        volumeButton.addTarget(self, action: #selector(volumeButtonDown), for: .touchDown)
        fullScreenButton.addTarget(self, action: #selector(fullScreenButtonDown), for: .touchDown)
        skipBackButton.addTarget(self, action: #selector(skipBackButtonDown), for: .touchDown)
        skipForwardButton.addTarget(self, action: #selector(skipForwardButtonDown), for: .touchDown)
        playButton.addTarget(self, action: #selector(playButtonDown), for: .touchDown)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(timeSliderPan(panGesture:)))
        timeSlider.addGestureRecognizer(panGesture)
        
        let tapTime = UITapGestureRecognizer(target: self, action: #selector(timeSliderTapped(tapGesture:)))
        timeSlider.addGestureRecognizer(tapTime)
        
        let panVolume = UIPanGestureRecognizer(target: self, action: #selector(volumeSliderPan(panGesture:)))
        volumeView.addGestureRecognizer(panVolume)
        
        let tapVolume = UITapGestureRecognizer(target: self, action: #selector(volumeSliderTapped(tapGesture:)))
        volumeView.addGestureRecognizer(tapVolume)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(tapGesture:)))
        self.addGestureRecognizer(tap)
        
        disableSeek()
        disableCaptions()
    }
}
