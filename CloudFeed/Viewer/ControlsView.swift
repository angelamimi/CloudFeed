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

    @IBOutlet weak var topStackView: UIStackView!
    @IBOutlet weak var volumeStackView: UIStackView!

    @IBOutlet weak var routeView: UIVisualEffectView!
    @IBOutlet weak var audioTrackView: UIVisualEffectView!
    @IBOutlet weak var volumeView: UIVisualEffectView!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    //@IBOutlet weak var timeView: UIVisualEffectView!
    //@IBOutlet weak var horizontalTimeView: UIVisualEffectView!

    @IBOutlet weak var controlsStackView: UIStackView!

    //@IBOutlet weak var horizontalTimeViewHeightConstraint: NSLayoutConstraint!

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

    @IBOutlet weak var routeButton: RouteView!

    weak var delegate: ControlsDelegate?
    var styleHasBackground: Bool = false

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

    required convenience init(style: Bool, frame: CGRect) {
        self.init(frame: frame)
        self.styleHasBackground = style
        commonInit()
    }

    private func commonInit() {

        guard let view = loadViewFromNib() else { return }

        view.frame = bounds

        addSubview(view)

        setPlaying(playing: false)
        initControls()

        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: Self, _) in
            self.onTraitChange()
        }
    }

    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: "ControlsView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        if volumeView.frame.contains(point)
            || topStackView.frame.contains(point)
            || controlsStackView.convert(controlsStackView.bounds, to: self).contains(point)
            || routeButton?.frame.contains(point) == true {
            return super.hitTest(point, with: event)
        }

        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if #unavailable(iOS 26) {
            audioViewLeadingConstraint.constant = 0
            volumeViewTrailingConstraint.constant = 0
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            audioViewLeadingConstraint.constant = 8
            volumeViewTrailingConstraint.constant = 8
        }
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
        //timeButton.configuration?.title = time
        timeButton.accessibilityLabel = Strings.ControlsCurrentTime.appending(" ").appending(time)

        let timeString = AttributedString(NSAttributedString(string: time, attributes: [.foregroundColor: UIColor.white]))
        timeButton.configuration?.attributedTitle = timeString
    }

    func setRemainingTime(time: String) {
       // totalTimeButton.configuration?.title = time
        totalTimeButton.accessibilityLabel = Strings.ControlsRemainingTime.appending(" ").appending(time)

        let timeString = AttributedString(NSAttributedString(string: time, attributes: [.foregroundColor: UIColor.white]))
        totalTimeButton.configuration?.attributedTitle = timeString
    }

    func setPlaying(playing: Bool) {

        isPlaying = playing

        if playing {
            playButton.configuration?.image = UIImage(systemName: "pause.circle.fill")
        } else {
            playButton.configuration?.image = UIImage(systemName: "play.circle.fill")
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

    func getTimeSlider() -> UISlider {
        if horizontalTimeSlider.isHidden == false {
            return horizontalTimeSlider
        } else {
            return verticalTimeSlider
        }
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

    @objc private func showVolumeFinished() {
        UIView.transition(with: volumeSlider, duration: 0.5, options: .curveLinear,
                          animations: { [weak self] in
            self?.volumeSlider.isHidden = true
        }, completion: { [weak self] _ in
            self?.volumeStackView.layoutMargins.left = 0
        })
    }

    @objc private func volumeButtonTapped() {

        if volumeSlider.isHidden {
            volumeSlider.isHidden = false

            volumeStackView.layoutMargins.left = 16

            perform(#selector(showVolumeFinished), with: nil, afterDelay: 4.0)

        } else {

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
            var value = Float(location.x / timeSlider.frame.width)

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
        let value = Float(location.x / timeSlider.frame.width)

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
            var value = Float(location.x / volumeSlider.frame.width) * 100

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
        let value = Float(location.x / volumeSlider.frame.width) * 100

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
        audioTrackButton.isHidden = !visible
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

        setTime(time: formattedTime)
        setRemainingTime(time: formattedTotalTime)
    }

    private func setVolumeButton(mute: Bool) {
        volumeButton.isSelected = mute
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
        timeButton.isEnabled = enabled
        totalTimeButton.isEnabled = enabled
    }

    private func highlightButton(button: UIButton) {
        button.tintColor = .secondaryLabel
        UIView.animate(withDuration: 0.4, animations: {
            button.tintColor = .label
        })
    }

    private func speedRateChanged(rate: Float) {
        delegate?.speedRateChanged(rate: rate)
    }

    private func buildSpeedRateMenu(currentRate: Float) -> UIMenu {

        let action025 = UIAction(title: Strings.ControlsSpeedRate025, state: currentRate == 0.25 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 0.25)
        }

        let action050 = UIAction(title: Strings.ControlsSpeedRate05, state: currentRate == 0.5 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 0.5)
        }

        let action075 = UIAction(title: Strings.ControlsSpeedRate075, state: currentRate == 0.75 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 0.75)
        }

        let action1 = UIAction(title: Strings.ControlsSpeedRate1, state: currentRate == 1.0 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 1.0)
        }

        let action125 = UIAction(title: Strings.ControlsSpeedRate125, state: currentRate == 1.25 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 1.25)
        }

        let action150 = UIAction(title: Strings.ControlsSpeedRate15, state: currentRate == 1.5 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 1.50)
        }

        let action175 = UIAction(title: Strings.ControlsSpeedRate175, state: currentRate == 1.75 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 1.75)
        }

        let action2 = UIAction(title: Strings.ControlsSpeedRate2, state: currentRate == 2.0 ? .on : .off) { [weak self] _ in
            self?.speedRateChanged(rate: 2.0)
        }

        let speedMenu = UIMenu(title: Strings.ControlsSpeedRateTitle,
                               image: nil,
                               options: [.singleSelection],
                               children: [action025, action050, action075, action1, action125, action150, action175, action2])

        return speedMenu
    }

    private func onTraitChange() {
        drawControlsCorners()
    }

    private func drawControlsCorners() {

        if traitCollection.verticalSizeClass == .compact {
            if #available(iOS 26, *) {
                controlsStackView.cornerConfiguration = .corners(radius: 8)
            } else {
                controlsStackView.clipsToBounds = true
                controlsStackView.layer.cornerRadius = 8
            }
        } else {
            if #available(iOS 26, *) {
                controlsStackView.cornerConfiguration = .corners(radius: 0)
            } else {
                controlsStackView.layer.cornerRadius = 0
            }
        }
    }

    private func initControls() {

        horizontalTimeSlider.accessibilityLabel = Strings.ControlsTime
        verticalTimeSlider.accessibilityLabel = Strings.ControlsTime
        speedButton.accessibilityLabel = Strings.ControlsSpeed
        volumeSlider.accessibilityLabel = Strings.ControlsVolume
        volumeButton.accessibilityLabel = Strings.ControlsVolume
        audioTrackButton.accessibilityLabel = Strings.ControlsAudioTrack

        timeButton.accessibilityHint = Strings.ControlsCurrentTimeHint
        totalTimeButton.accessibilityHint = Strings.ControlsRemainingTimeHint

        //timeButton.maximumContentSizeCategory = .accessibilityExtraLarge
        //totalTimeButton.maximumContentSizeCategory = .accessibilityExtraLarge

        drawControlsCorners()

        controlsView.effect = .none

        if styleHasBackground {
            controlsStackView.backgroundColor = .black.withAlphaComponent(0.5)
        } else {
            controlsStackView.backgroundColor = .clear
        }

        volumeButton.configurationUpdateHandler = { button in

            button.configuration?.background.backgroundColor = .clear

            if button.isSelected {
                button.configuration?.image = UIImage(systemName: "speaker.slash")
            } else {
                button.configuration?.image = UIImage(systemName: "speaker.wave.2")
            }
        }

        volumeButton.configuration?.image = UIImage(systemName: "speaker.wave.2")

        volumeButton.configuration?.background.backgroundColorTransformer = .init { _ in
            return .clear
        }

        if styleHasBackground {
            volumeView.effect = .none
            volumeView.backgroundColor = .black.withAlphaComponent(0.3)

            if #available(iOS 26, *) {
                volumeView.cornerConfiguration = .capsule()
            } else {
                volumeView.clipsToBounds = true
                volumeView.layer.cornerRadius = 8
            }
        } else {
            volumeView.effect = .none
            volumeView.backgroundColor = .clear
        }

        audioTrackView.effect = .none

        if styleHasBackground {
            audioTrackView.backgroundColor = .black.withAlphaComponent(0.3)

            if #available(iOS 26, *) {
                audioTrackView.cornerConfiguration = .capsule()
            } else {
                audioTrackView.clipsToBounds = true
                audioTrackView.layer.cornerRadius = 8
            }
        } else {
            audioTrackView.backgroundColor = .clear
        }

        routeView.effect = .none

        if styleHasBackground {
            routeView.backgroundColor = .black.withAlphaComponent(0.3)

            if #available(iOS 26, *) {
                routeView.cornerConfiguration = .capsule()
            } else {
                routeView.clipsToBounds = true
                routeView.layer.cornerRadius = 8
            }
        } else {
            routeView.backgroundColor = .clear
        }

        let disabledForegroundColor: UIColor = styleHasBackground ? .white.withAlphaComponent(0.3) : .gray.withAlphaComponent(0.8)

        volumeButton.configuration = .plain()
        volumeButton.configuration?.baseForegroundColor = .white
        volumeButton.configuration?.image = UIImage(systemName: "speaker.wave.2")
        volumeButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        volumeButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak volumeButton] baseColor in
            return volumeButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        playButton.configuration = .plain()
        playButton.configuration?.baseForegroundColor = .white
        playButton.configuration?.image = UIImage(systemName: "play.circle.fill")
        playButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 46)
        playButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak playButton] baseColor in
            return playButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        skipBackButton.configuration = .plain()
        skipBackButton.configuration?.baseForegroundColor = .white
        skipBackButton.configuration?.image = UIImage(systemName: "backward.fill")
        skipBackButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        skipBackButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak skipBackButton] baseColor in
            return skipBackButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        skipForwardButton.configuration = .plain()
        skipForwardButton.configuration?.baseForegroundColor = .white
        skipForwardButton.configuration?.image = UIImage(systemName: "forward.fill")
        skipForwardButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        skipForwardButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak skipForwardButton] baseColor in
            return skipForwardButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        captionsButton.configuration = .plain()
        captionsButton.configuration?.baseForegroundColor = .white
        captionsButton.configuration?.image = UIImage(systemName: "captions.bubble")
        captionsButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        captionsButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak captionsButton] baseColor in
            return captionsButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        speedButton.configuration = .plain()
        speedButton.configuration?.baseForegroundColor = .white
        speedButton.configuration?.image = UIImage(systemName: "gauge.with.dots.needle.100percent")
        speedButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        speedButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak speedButton] baseColor in
            return speedButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        audioTrackButton.configuration = .plain()
        audioTrackButton.configuration?.baseForegroundColor = .white
        audioTrackButton.configuration?.image = UIImage(systemName: "waveform")
        audioTrackButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
        audioTrackButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer({ [weak audioTrackButton] baseColor in
            return audioTrackButton?.state == .disabled ? disabledForegroundColor : baseColor
        })

        let timeString = AttributedString(NSAttributedString(string: "", attributes: [.foregroundColor: UIColor.white]))

        timeButton.configuration = .plain()
        timeButton.configuration?.titleLineBreakMode = .byTruncatingHead
        timeButton.configuration?.baseForegroundColor = .white
        timeButton.configuration?.attributedTitle = timeString
        timeButton.configuration?.contentInsets = .zero
        timeButton.isEnabled = false
        timeButton.configurationUpdateHandler = { button in
            let titleColor: UIColor = button.state == .disabled ? disabledForegroundColor : .white
            button.configuration?.attributedTitle?.foregroundColor = titleColor
        }

        totalTimeButton.configuration = .plain()
        totalTimeButton.configuration?.titleLineBreakMode = .byTruncatingHead
        totalTimeButton.configuration?.baseForegroundColor = .white
        totalTimeButton.configuration?.attributedTitle = timeString
        totalTimeButton.configuration?.contentInsets = .zero
        totalTimeButton.isEnabled = false
        totalTimeButton.configurationUpdateHandler = { button in
            let titleColor: UIColor = button.state == .disabled ? disabledForegroundColor : .white
            button.configuration?.attributedTitle?.foregroundColor = titleColor
        }

        controlsViewTopConstraint.isActive = true
        controlsStackViewTopConstraint.isActive = false

        captionsButton.configuration?.contentInsets = .zero
        speedButton.configuration?.contentInsets = .zero

        horizontalTimeSlider.minimumTrackTintColor = .white
        horizontalTimeSlider.maximumTrackTintColor = .tintColor
        horizontalTimeSlider.tintColor = disabledForegroundColor

        if #available(iOS 26, *) {
            horizontalTimeSlider.sliderStyle = .thumbless
        }

        verticalTimeSlider.minimumTrackTintColor = .white
        verticalTimeSlider.maximumTrackTintColor = .tintColor
        verticalTimeSlider.tintColor = disabledForegroundColor

        if #available(iOS 26, *) {
            verticalTimeSlider.sliderStyle = .thumbless
        }

        volumeSlider.minimumTrackTintColor = .white
        volumeSlider.maximumTrackTintColor = .tintColor
        volumeSlider.tintColor = disabledForegroundColor

        if #available(iOS 26, *) {
            volumeSlider.sliderStyle = .thumbless
        }

        audioTrackButton.configuration?.image = UIImage(systemName: "waveform")
        audioTrackButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)

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

        setTime(time: "00:00")
        setRemainingTime(time: "00:00")

        disableSeek()
        disableCaptions()
        disableAudioTracks()
    }
}
