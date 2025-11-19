//
//  PasscodeController.swift
//  CloudFeed
//
//  Created by Angela Jarosz on 10/15/25.
//  Copyright © 2025 Angela Jarosz. All rights reserved.
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
protocol PasscodeDelegate: AnyObject {
    func unlock()
}

class PasscodeController: UIViewController {
    
    @IBOutlet weak var containterView: UIVisualEffectView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var codeStackView: UIStackView!
    @IBOutlet weak var labelStackView: UIStackView!
    
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var codeView0: UIView!
    @IBOutlet weak var codeView1: UIView!
    @IBOutlet weak var codeView2: UIView!
    @IBOutlet weak var codeView3: UIView!
    @IBOutlet weak var codeView4: UIView!
    @IBOutlet weak var codeView5: UIView!
    
    @IBOutlet weak var button0: UIButton!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var button3: UIButton!
    @IBOutlet weak var button4: UIButton!
    @IBOutlet weak var button5: UIButton!
    @IBOutlet weak var button6: UIButton!
    @IBOutlet weak var button7: UIButton!
    @IBOutlet weak var button8: UIButton!
    @IBOutlet weak var button9: UIButton!
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var passcode: String = ""
    var initialPasscode: String?
    var mode: Global.PasscodeMode = .unlock
    
    var viewModel: PasscodeViewModel?
    weak var delegate: PasscodeDelegate?
    
    @IBAction func button0Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad0, button: sender as! UIButton)
    }

    @IBAction func button1Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad1, button: sender as! UIButton)
    }
    
    @IBAction func button2Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad2, button: sender as! UIButton)
    }
    
    @IBAction func button3Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad3, button: sender as! UIButton)
    }
    
    @IBAction func button4Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad4, button: sender as! UIButton)
    }
    
    @IBAction func button5Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad5, button: sender as! UIButton)
    }
    
    @IBAction func button6Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad6, button: sender as! UIButton)
    }
    
    @IBAction func button7Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad7, button: sender as! UIButton)
    }
    
    @IBAction func button8Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad8, button: sender as! UIButton)
    }
    
    @IBAction func button9Touched(_ sender: Any) {
        handleButtonTouched(value: Strings.PasscodeNumberPad9, button: sender as! UIButton)
    }
    
    @IBAction func cancelButtonTouched(_ sender: Any) {
        handleCancel()
    }
    
    @IBAction func deleteButtonTouched(_ sender: Any) {
        handleDelete()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deleteButton.setTitle(Strings.DeleteAction, for: .normal)
        cancelButton.setTitle(Strings.CancelAction, for: .normal)

        initConfigurations()
        initInstructions()
        
        cancelButton.isHidden = true
        deleteButton.isHidden = true
        
        if isModalInPresentation {
            containterView.isHidden = false
            view.backgroundColor = .clear
        } else {
            containterView.isHidden = true
            view.backgroundColor = .systemGroupedBackground
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clearCode()
    }
    
    private func initInstructions() {
        
        var text = ""
        
        switch mode {
        case .create:
            text = Strings.PasscodeCreate
        case .unlock:
            text = Strings.PasscodeEnter
        case .validate:
            text = Strings.PasscodeValidate
        case .delete:
            text = Strings.PasscodeEnter
        }
        
        label.text = text
    }
    
    private func initConfigurations() {
        
        view.maximumContentSizeCategory = .accessibilityLarge
        
        setPasscodeViewBorderWidth()
        setPasscodeViewCornerRadius()
        setPasscodeViewBorderColor()
        
        setNumberPadConfigurations()
    }
    
    private func setPasscodeViewBorderColor() {
        let color = UIColor.label.cgColor
        codeView0.layer.borderColor = color
        codeView1.layer.borderColor = color
        codeView2.layer.borderColor = color
        codeView3.layer.borderColor = color
        codeView4.layer.borderColor = color
        codeView5.layer.borderColor = color
    }
    
    private func setPasscodeViewCornerRadius() {
        let cornerRadius = 10.0
        codeView0.layer.cornerRadius = cornerRadius
        codeView1.layer.cornerRadius = cornerRadius
        codeView2.layer.cornerRadius = cornerRadius
        codeView3.layer.cornerRadius = cornerRadius
        codeView4.layer.cornerRadius = cornerRadius
        codeView5.layer.cornerRadius = cornerRadius
    }
    
    private func setPasscodeViewBorderWidth() {
        let borderWidth = 1.0
        codeView0.layer.borderWidth = borderWidth
        codeView1.layer.borderWidth = borderWidth
        codeView2.layer.borderWidth = borderWidth
        codeView3.layer.borderWidth = borderWidth
        codeView4.layer.borderWidth = borderWidth
        codeView5.layer.borderWidth = borderWidth
    }
    
    private func setNumberPadConfigurations() {
        
        if #available(iOS 26.0, *) {
            
            //containterView.effect = UIGlassEffect(style: .regular)
            
            var borderedGlassConfig = UIButton.Configuration.glass()
            
            borderedGlassConfig.background.strokeWidth = 1
            borderedGlassConfig.background.strokeColor = .secondaryLabel
            
            button0.configuration = borderedGlassConfig
            button1.configuration = borderedGlassConfig
            button2.configuration = borderedGlassConfig
            button3.configuration = borderedGlassConfig
            button4.configuration = borderedGlassConfig
            button5.configuration = borderedGlassConfig
            button6.configuration = borderedGlassConfig
            button7.configuration = borderedGlassConfig
            button8.configuration = borderedGlassConfig
            button9.configuration = borderedGlassConfig
            
        } else {
            
            var config = UIButton.Configuration.bordered()
            
            config.cornerStyle = .capsule
            config.background.strokeWidth = 1
            config.background.strokeColor = .secondaryLabel
            config.baseForegroundColor = .label
            
            button0.configuration = config
            button1.configuration = config
            button2.configuration = config
            button3.configuration = config
            button4.configuration = config
            button5.configuration = config
            button6.configuration = config
            button7.configuration = config
            button8.configuration = config
            button9.configuration = config
            
            setButtonConfigurationUpdateHandler(button0)
            setButtonConfigurationUpdateHandler(button1)
            setButtonConfigurationUpdateHandler(button2)
            setButtonConfigurationUpdateHandler(button3)
            setButtonConfigurationUpdateHandler(button4)
            setButtonConfigurationUpdateHandler(button5)
            setButtonConfigurationUpdateHandler(button6)
            setButtonConfigurationUpdateHandler(button7)
            setButtonConfigurationUpdateHandler(button8)
            setButtonConfigurationUpdateHandler(button9)
        }
        
        button0.configuration?.title = Strings.PasscodeNumberPad0
        button1.configuration?.title = Strings.PasscodeNumberPad1
        button2.configuration?.title = Strings.PasscodeNumberPad2
        button3.configuration?.title = Strings.PasscodeNumberPad3
        button4.configuration?.title = Strings.PasscodeNumberPad4
        button5.configuration?.title = Strings.PasscodeNumberPad5
        button6.configuration?.title = Strings.PasscodeNumberPad6
        button7.configuration?.title = Strings.PasscodeNumberPad7
        button8.configuration?.title = Strings.PasscodeNumberPad8
        button9.configuration?.title = Strings.PasscodeNumberPad9
    }
    
    private func setButtonConfigurationUpdateHandler(_ numberButton: UIButton) {
        numberButton.configurationUpdateHandler = { button in
            button.configuration?.baseBackgroundColor = button.isHighlighted ? .secondarySystemFill : .clear
        }
    }
    
    private func handleCancel() {
        
    }
    
    private func handleDelete() {
        
        guard passcode.count > 0 else { return }
        
        let count = passcode.count
        
        passcode.removeLast()
        
        if count == 6 {
            unhighlightView(view: codeView5)
        } else if count == 5 {
            unhighlightView(view: codeView4)
        } else if count == 4 {
            unhighlightView(view: codeView3)
        } else if count == 3 {
            unhighlightView(view: codeView2)
        } else if count == 2 {
            unhighlightView(view: codeView1)
        } else if count == 1 {
            unhighlightView(view: codeView0)
            deleteButton.isHidden = true
        }
    }
    
    private func handleButtonTouched(value: String, button: UIButton) {
        
        guard passcode.count < 6 else { return }
        
        passcode = passcode + value
        
        let count = passcode.count
        
        if count == 1 {
            deleteButton.isHidden = false
            highlightView(view: codeView0)
        } else if count == 2 {
            highlightView(view: codeView1)
        } else if count == 3 {
            highlightView(view: codeView2)
        } else if count == 4 {
            highlightView(view: codeView3)
        } else if count == 5 {
            highlightView(view: codeView4)
        } else if count == 6 {
            highlightView(view: codeView5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.handlePasscodeEntered()
            }
        }
    }
    
    private func handlePasscodeEntered() {
        
        if mode == .create {
            viewModel?.handlePasscodeCreation(passcode)
        } else if mode == .validate {
            if passcode == initialPasscode {
                viewModel?.savePasscode(passcode)
            } else {
                handlePasscodeFail()
            }
        } else if mode == .delete {
            if viewModel?.passcodeUnlock(passcode) ?? false {
                viewModel?.resetFailedPasscodeCount()
                viewModel?.deletePasscode()
            } else {
                handlePasscodeFail()
            }
        } else {
            if viewModel?.passcodeUnlock(passcode) ?? false {
                viewModel?.resetFailedPasscodeCount()
                delegate?.unlock()
            } else {
                handlePasscodeFail()
            }
        }
    }
    
    private func handlePasscodeFail() {
        
        shake(codeStackView)
        clearCode()
        
        if mode == .validate {
            return
        }
        
        viewModel?.incrementFailedPasscodeCount()
        
        if viewModel?.getAppResetOnFailedAttempts() ?? false {
            
            if let failCount = viewModel?.getFailedPasscodeCount(), failCount >= Global.shared.maxPasscodeAttempts {
                viewModel?.reset()
            }
        }
    }
    
    private func highlightView(view: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            view.backgroundColor = .label
        })
    }
    
    private func unhighlightView(view: UIView) {
        UIView.animate(withDuration: 0.3, animations: {
            view.backgroundColor = .clear
        })
    }
    
    private func clearCode() {
        
        passcode = ""
        
        unhighlightView(view: codeView0)
        unhighlightView(view: codeView1)
        unhighlightView(view: codeView2)
        unhighlightView(view: codeView3)
        unhighlightView(view: codeView4)
        unhighlightView(view: codeView5)
        
        deleteButton.isHidden = true
    }
    
    private func shake(_ shakeView: UIView) {
        
        let x = 5.0
        let speed = 0.75
        let time = 1.0 * speed - 0.15
        let timeFactor = CGFloat(time / 4)
        let animationDelays = [timeFactor, timeFactor * 2, timeFactor * 3]
        let shakeAnimator = UIViewPropertyAnimator(duration: time, dampingRatio: 0.3)

        shakeAnimator.addAnimations({
            shakeView.transform = CGAffineTransform(translationX: x, y: 0)
        })
        
        shakeAnimator.addAnimations({
            shakeView.transform = CGAffineTransform(translationX: -x, y: 0)
        }, delayFactor: animationDelays[0])
        
        shakeAnimator.addAnimations({
            shakeView.transform = CGAffineTransform(translationX: x, y: 0)
        }, delayFactor: animationDelays[1])
        
        shakeAnimator.addAnimations({
            shakeView.transform = CGAffineTransform(translationX: 0, y: 0)
        }, delayFactor: animationDelays[2])

        shakeAnimator.startAnimation()
    }
}
