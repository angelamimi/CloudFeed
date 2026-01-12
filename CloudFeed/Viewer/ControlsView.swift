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

import AVKit
import UIKit

@MainActor
protocol ControlsDelegate: AnyObject {
    
    func beganTracking()
    func timeChanged(time: Float)
    func volumeChanged(volume: Float)
    func speedRateChanged(rate: Float)
    
    func volumeButtonTapped()
    func playButtonTapped()
    func fullScreenButtonTapped()
    
    func captionsSelected(subtitleIndex: Int32)
    func audioTrackSelected(audioTrackIndex: Int32)
}

class ControlsView: UIView {
    
    @IBOutlet weak var audioTrackView: UIVisualEffectView!
    @IBOutlet weak var volumeView: UIVisualEffectView!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    @IBOutlet weak var timeView: UIVisualEffectView!
    @IBOutlet weak var horizontalTimeView: UIVisualEffectView!
    
    @IBOutlet weak var controlsStackView: UIStackView!
    
    @IBOutlet weak var horizontalTimeViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var controlsViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var controlsStackViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var timeSliderLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var timeSliderTrailingConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var audioTrackButton: UIButton!
    
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var volumeButton: UIButton!
    @IBOutlet weak var volumeTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var verticalTimeSlider: UISlider!
    @IBOutlet weak var horizontalTimeSlider: UISlider!
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    
    @IBOutlet weak var timeButton: UIButton!
    @IBOutlet weak var totalTimeButton: UIButton!
    
    @IBOutlet weak var captionsButton: UIButton!
    @IBOutlet weak var skipBackButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var skipForwardButton: UIButton!
    @IBOutlet weak var speedButton: UIButton!
    
    @IBOutlet weak var speedButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var captionsButtonWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var volumeViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioViewLeadingConstraint: NSLayoutConstraint!
    
    weak var delegate: ControlsDelegate?
    var glass: Bool = false
    
    private var volume: Int = 100 // 0% for mute, 100% for full volume
    private var isPlaying: Bool = false
    private var length: Double = 0
    private let skipSeconds: Double = 10.0
    private let endSeconds: Float = 10.0
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required convenience init(glass: Bool, frame: CGRect) {
        self.init(frame: frame)
        self.glass = glass
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        if volumeView.frame.contains(point)
            || audioTrackView.frame.contains(point)
            || controlsStackView.convert(controlsStackView.bounds, to: self).contains(point) {
            return super.hitTest(point, with: event)
        }
        
        return nil
    }
    
    func reset() {
        setPosition(position: 0)
        setTime(time: "00:00")
        setRemainingTime(time: "00:00")
        setPlaying(playing: false)
        
        disableSeek()
        disableCaptions()
        disableAudioTracks()
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
    
    func disableAudioTracks() {
        audioTrackButton.isEnabled = false
    }
    
    func setMediaLength(length: Double) {
        self.length = length
        
        skipBackButton.isEnabled = true
        skipForwardButton.isEnabled = true
    }
    
    func setPosition(position: Float) {
        let timeSlider = getTimeSlider()
        if position >= timeSlider.minimumValue && position <= timeSlider.maximumValue {
            timeSlider.setValue(position, animated: true)
        }
    }
    
    func setTime(time: String) {
        timeLabel.text = time
        timeButton.setTitle(time, for: .normal)
    }
    
    func setRemainingTime(time: String) {
        totalTimeLabel.text = time
        totalTimeButton.setTitle(time, for: .normal)
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
    
    func selectAudioTrack(currentAudioTrackIndex: Int32) {
        
        guard let menu = audioTrackButton.menu else { return }

        for case let option as UIAction in menu.children {
            if option.identifier == UIAction.Identifier(String(currentAudioTrackIndex)) {
                option.state = .on
            } else {
                option.state = .off
            }
        }
    }
    
    func initCaptionsMenu(currentSubtitleIndex: Int32?, subtitleIndexes: [Any], subtitleNames: [Any]) {
        
        guard captionsButton.menu == nil else {
            captionsButton.isEnabled = true
            return
        }
        
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
    
    func initAudioTrackMenu(currentAudioTrackIndex: Int32?, audioTrackIndexes: [Any], audioTrackNames: [Any]) {
        
        guard audioTrackButton.menu == nil else {
            audioTrackButton.isEnabled = true
            setAudioTrackButtonVisibility(visible: true)
            return
        }
        
        if audioTrackNames.count == 0 {
            setAudioTrackButtonVisibility(visible: false)
            return
        }
        
        var menuChildren: [UIMenuElement] = []
        
        for index in 0...audioTrackNames.count - 1 {
            
            guard let audioTrackTitle = audioTrackNames[index] as? String, let audioTrackIndex = audioTrackIndexes[index] as? Int32 else {
                audioTrackButton.isEnabled = false
                return
            }
            
            let action = UIAction(title: audioTrackTitle, identifier: UIAction.Identifier(rawValue: String(audioTrackIndex))) { [weak self] _ in
                self?.delegate?.audioTrackSelected(audioTrackIndex: audioTrackIndex)
            }
            
            if currentAudioTrackIndex != nil && audioTrackIndex == currentAudioTrackIndex {
                action.state = .on
            }
            
            menuChildren.append(action)
        }
        
        audioTrackButton.menu = UIMenu(options: .displayInline, children: menuChildren)
        
        audioTrackButton.showsMenuAsPrimaryAction = true
        audioTrackButton.changesSelectionAsPrimaryAction = false
        audioTrackButton.isEnabled = true
        setAudioTrackButtonVisibility(visible: true)
    }
    
    @objc private func volumeChanged() {

        delegate?.volumeChanged(volume: volumeSlider.value)
        
        if volumeSlider.value == 0 {
            setVolumeButton(mute: true)
        } else {
            setVolumeButton(mute: false)
        }
    }

    @objc private func timeChanged(_ timeSlider: UISlider) {
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
        
        guard let timeSlider = panGesture.view as? UISlider else { return }
        
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
        
        guard let timeSlider = tapGesture.view as? UISlider else { return }
        
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
    
    @objc private func timeButtonTapped(tapGesture: UITapGestureRecognizer) {
        horizontalTimeSlider.value = 0
        verticalTimeSlider.value = 0
        setTimeLabelFromPosition(0)
        delegate?.timeChanged(time: 0)
    }
    
    @objc private func totalTimeButtonTapped(tapGesture: UITapGestureRecognizer) {
        
        guard length > 0 else { return }
        
        let totalSeconds = Float(length / 1_000)
        var newTime: Float
        
        if totalSeconds >= endSeconds * 2 {
            newTime = totalSeconds - endSeconds
        } else {
            newTime = totalSeconds / 2
        }
        
        var newPosition = newTime / totalSeconds
        let timeSlider = getTimeSlider()
        
        if newPosition < timeSlider.minimumValue {
            newPosition = 0
        } else if newPosition > timeSlider.maximumValue {
            newPosition = 1
        }
        
        horizontalTimeSlider.value = newPosition
        verticalTimeSlider.value = newPosition
        
        setTimeLabelFromPosition(newPosition)
        
        delegate?.timeChanged(time: newPosition)
    }
    
    private func setAudioTrackButtonVisibility(visible: Bool) {
        audioTrackView.isHidden = !visible
    }
    
    private func skip(forward: Bool) {
        
        guard length > 0 else { return }
        
        let timeSlider = getTimeSlider()
        let mediaLength = length / 1_000
        let currentTime = Double(timeSlider.value) * mediaLength
        var newTime: Double
        
        if forward {
            newTime = currentTime + skipSeconds
        } else {
            newTime = currentTime - skipSeconds
        }
        
        var newPosition = Float(newTime / mediaLength)

        if newPosition < timeSlider.minimumValue {
            newPosition = 0
        } else if newPosition > timeSlider.maximumValue {
            newPosition = 1
        }
        
        horizontalTimeSlider.value = newPosition
        verticalTimeSlider.value = newPosition
        
        setTimeLabelFromPosition(newPosition)
        
        delegate?.timeChanged(time: newPosition)
    }
    
    private func setTimeLabelFromPosition(_ position: Float) {
        
        let lengthSeconds = length / 1_000
        let timeValue = lengthSeconds * Double(position)
        let remainingValue = lengthSeconds - timeValue
        let formatter = DateComponentsFormatter()
       
        formatter.allowedUnits = timeValue >= (60 * 60) ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        
        let formattedTime = formatter.string(from: TimeInterval(timeValue))!
        let formattedTotalTime = "-\(formatter.string(from: TimeInterval(remainingValue))!)"
        
        timeLabel.text = formattedTime
        totalTimeLabel.text = formattedTotalTime
        
        timeButton.setTitle(formattedTime, for: .normal)
        totalTimeButton.setTitle(formattedTotalTime, for: .normal)
    }
    
    private func setVolumeButton(mute: Bool) {
        if mute {
            volumeButton.setImage(UIImage(systemName: "speaker.slash"), for: .normal)
        } else {
            volumeButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        }
    }
    
    private func setIsEnabled(enabled: Bool) {
        audioTrackButton.isEnabled = enabled
        volumeButton.isEnabled = enabled
        volumeSlider.isEnabled = enabled
        verticalTimeSlider.isEnabled = enabled
        horizontalTimeSlider.isEnabled = enabled
        captionsButton.isEnabled = enabled
        playButton.isEnabled = enabled
        speedButton.isEnabled = enabled
        timeLabel.isEnabled = enabled
        totalTimeLabel.isEnabled = enabled
        timeButton.isEnabled = enabled
        totalTimeButton.isEnabled = enabled
        skipBackButton.isEnabled = enabled
        skipForwardButton.isEnabled = enabled
    }
    
    private func setSeekIsEnabled(enabled: Bool) {
        verticalTimeSlider.isEnabled = enabled
        horizontalTimeSlider.isEnabled = enabled
        skipBackButton.isEnabled = enabled
        skipForwardButton.isEnabled = enabled
        speedButton.isEnabled = enabled
    }
    
    private func highlightButton(button: UIButton) {
        button.tintColor = .secondaryLabel
        UIView.animate(withDuration: 0.4, animations: {
            button.tintColor = .label
        })
    }
    
    func getTimeSlider() -> UISlider {
        if horizontalTimeView.isHidden == false {
            return horizontalTimeSlider
        } else {
            return verticalTimeSlider
        }
    }
    
    private func speedRateChanged(rate: Float) {
        delegate?.speedRateChanged(rate: rate)
    }
    
    private func buildSpeedRateMenu(currentRate: Float) -> UIMenu {
        
        let action025 = UIAction(title: Strings.ControlsSpeedRate025, state: currentRate == 0.25 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 0.25)
        }
    
        let action050 = UIAction(title: Strings.ControlsSpeedRate05, state: currentRate == 0.5 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 0.5)
        }
        
        let action075 = UIAction(title: Strings.ControlsSpeedRate075, state: currentRate == 0.75 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 0.75)
        }
        
        let action1 = UIAction(title: Strings.ControlsSpeedRate1, state: currentRate == 1.0 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 1.0)
        }
        
        let action125 = UIAction(title: Strings.ControlsSpeedRate125, state: currentRate == 1.25 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 1.25)
        }
        
        let action150 = UIAction(title: Strings.ControlsSpeedRate15, state: currentRate == 1.5 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 1.50)
        }
        
        let action175 = UIAction(title: Strings.ControlsSpeedRate175, state: currentRate == 1.75 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 1.75)
        }
        
        let action2 = UIAction(title: Strings.ControlsSpeedRate2, state: currentRate == 2.0 ? .on : .off) { [weak self] action in
            self?.speedRateChanged(rate: 2.0)
        }

        let speedMenu = UIMenu(title: Strings.ControlsSpeedRateTitle,
                               image: nil,
                               options: [.singleSelection],
                               children: [action025, action050, action075, action1, action125, action150, action175, action2])
        
        return speedMenu
    }
    
    private func initControls() {
        
        timeLabel.maximumContentSizeCategory = .accessibilityExtraLarge
        totalTimeLabel.maximumContentSizeCategory = .accessibilityExtraLarge
        
        timeButton.maximumContentSizeCategory = .accessibilityExtraLarge
        totalTimeButton.maximumContentSizeCategory = .accessibilityExtraLarge
        
        audioTrackButton.setImage(UIImage(systemName: "waveform"), for: .normal)
        audioTrackButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
        
        if #available(iOS 26, *), glass {
            
            let glassEffect = UIGlassEffect()
            
            glassEffect.isInteractive = true
            
            volumeView.effect = glassEffect
            volumeView.cornerConfiguration = .capsule()
            
            horizontalTimeView.effect = glassEffect
            horizontalTimeView.cornerConfiguration = .capsule()
            
            timeView.effect = glassEffect
            timeView.cornerConfiguration = .capsule()
            
            audioTrackButton.configuration = .glass()

            controlsView.effect = UIGlassContainerEffect()
            audioTrackView.effect = UIGlassContainerEffect()
            
            playButton.configuration = .glass()
            playButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            playButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 46), forImageIn: .normal)
            
            skipBackButton.configuration = .glass()
            skipBackButton.setImage(UIImage(systemName: "backward.fill"), for: .normal)
            skipBackButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
            
            skipForwardButton.configuration = .glass()
            skipForwardButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
            skipForwardButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
            
            captionsButton.configuration = .glass()
            captionsButton.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
            captionsButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
            
            speedButton.configuration = .glass()
            speedButton.setImage(UIImage(systemName: "gauge.with.dots.needle.100percent"), for: .normal)
            speedButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
            
            timeButton.configuration = .glass()
            timeButton.configuration?.titleLineBreakMode = .byTruncatingHead
            timeButton.setTitle("00:00", for: .normal)
            
            totalTimeButton.configuration = .glass()
            totalTimeButton.configuration?.titleLineBreakMode = .byTruncatingHead
            totalTimeButton.setTitle("00:00", for: .normal)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                volumeViewTrailingConstraint.constant = 8
                audioViewLeadingConstraint.constant = 8
            }
            
            controlsViewTopConstraint.isActive = true
            controlsStackViewTopConstraint.isActive = false
            
            controlsStackView.spacing = 16
            
            horizontalTimeViewHeightConstraint.constant = 50
            
        } else {
            
            timeView.effect = .none
            timeView.backgroundColor = .clear
            
            horizontalTimeView.effect = .none
            horizontalTimeView.backgroundColor = .clear
            
            if #available(iOS 26, *) {
                volumeView.effect = UIGlassEffect()
                volumeView.cornerConfiguration = .capsule()
                
                audioTrackButton.configuration = .glass()
                audioTrackView.effect = UIGlassContainerEffect()
            } else {
                
                audioTrackView.clipsToBounds = true
                audioTrackView.layer.cornerRadius = 8
                
                volumeView.clipsToBounds = true
                volumeView.layer.cornerRadius = 8
            }
            
            controlsView.clipsToBounds = true
            controlsView.layer.cornerRadius = 8
            
            timeButton.configuration = .plain()
            timeButton.configuration?.titleLineBreakMode = .byTruncatingHead
            timeButton.configuration?.contentInsets = .zero
            timeButton.setTitle("00:00", for: .normal)
            
            totalTimeButton.configuration = .plain()
            totalTimeButton.configuration?.titleLineBreakMode = .byTruncatingHead
            totalTimeButton.configuration?.contentInsets = .zero
            totalTimeButton.setTitle("00:00", for: .normal)

            speedButton.contentHorizontalAlignment = .trailing
            captionsButton.contentHorizontalAlignment = .leading
            
            speedButton.contentVerticalAlignment = .bottom
            captionsButton.contentVerticalAlignment = .bottom
            
            volumeViewTrailingConstraint.constant = 0
            audioViewLeadingConstraint.constant = 0
            
            controlsViewTopConstraint.isActive = false
            controlsStackViewTopConstraint.isActive = true
            
            timeSliderLeadingConstraint.constant = 0
            timeSliderTrailingConstraint.constant = 0
            
            horizontalTimeViewHeightConstraint.constant = 30
        }
        
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        
        horizontalTimeSlider.addTarget(self, action: #selector(timeChanged(_:)), for: .valueChanged)
        verticalTimeSlider.addTarget(self, action: #selector(timeChanged(_:)), for: .valueChanged)
        
        volumeButton.addTarget(self, action: #selector(volumeButtonTapped), for: .touchUpInside)
        skipBackButton.addTarget(self, action: #selector(skipBackButtonTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        skipForwardButton.addTarget(self, action: #selector(skipForwardButtonTapped), for: .touchUpInside)
        
        volumeButton.addTarget(self, action: #selector(volumeButtonDown), for: .touchDown)
        skipBackButton.addTarget(self, action: #selector(skipBackButtonDown), for: .touchDown)
        skipForwardButton.addTarget(self, action: #selector(skipForwardButtonDown), for: .touchDown)
        playButton.addTarget(self, action: #selector(playButtonDown), for: .touchDown)
        
        speedButton.showsMenuAsPrimaryAction = true
        speedButton.menu = buildSpeedRateMenu(currentRate: 1.0)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(timeSliderPan(panGesture:)))
        horizontalTimeSlider.addGestureRecognizer(panGesture)
        verticalTimeSlider.addGestureRecognizer(panGesture)
        
        let tapTime = UITapGestureRecognizer(target: self, action: #selector(timeSliderTapped(tapGesture:)))
        horizontalTimeSlider.addGestureRecognizer(tapTime)
        verticalTimeSlider.addGestureRecognizer(tapTime)
        
        let panVolume = UIPanGestureRecognizer(target: self, action: #selector(volumeSliderPan(panGesture:)))
        volumeView.addGestureRecognizer(panVolume)
        
        let tapVolume = UITapGestureRecognizer(target: self, action: #selector(volumeSliderTapped(tapGesture:)))
        volumeView.addGestureRecognizer(tapVolume)
        
        let tapBeginning = UITapGestureRecognizer(target: self, action: #selector(timeButtonTapped(tapGesture:)))
        timeButton.addGestureRecognizer(tapBeginning)
        
        let tapEnd = UITapGestureRecognizer(target: self, action: #selector(totalTimeButtonTapped(tapGesture:)))
        totalTimeButton.addGestureRecognizer(tapEnd)
        
        disableSeek()
        disableCaptions()
        disableAudioTracks()
    }
}
