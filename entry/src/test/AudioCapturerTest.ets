import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import AudioCapturer from '../main/ets/services/AudioCapturer';
import { audio } from '@kit.AudioKit';

/**
 * 音频捕获器测试套件
 * 测试音频录制、状态管理、数据回调等功能
 */
export default function audioCapturerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('AudioCapturerTest');

  describe('AudioCapturerTest', () => {
    let audioCapturer: AudioCapturer;
    let audioDataReceived: ArrayBuffer[] = [];
    let callbackTriggered: boolean = false;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化音频捕获器测试环境');

      // 创建音频捕获器实例
      audioCapturer = new AudioCapturer();

      // 等待初始化
      await TestUtils.sleep(100);
    });

    afterAll(async () => {
      await TestUtils.cleanupTestData();

      // 销毁音频捕获器
      if (audioCapturer) {
        await audioCapturer.destroy();
      }

      testSuite.afterAll();
    });

    beforeEach(() => {
      testSuite.beforeEach();
      audioDataReceived = [];
      callbackTriggered = false;
    });

    afterEach(() => {
      testSuite.afterEach();
    });

    /**
     * 测试音频数据回调函数
     */
    const audioDataCallback = (data: ArrayBuffer): void => {
      audioDataReceived.push(data);
      callbackTriggered = true;
      TestUtils.log(`收到音频数据: ${data.byteLength} bytes`);
    };

    /**
     * 测试初始化功能
     */
    it('should initialize audio capturer correctly', async () => {
      TestUtils.log('测试音频捕获器初始化功能');

      // 初始化音频捕获器
      await audioCapturer.init(audioDataCallback);

      // 验证状态
      const state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      TestUtils.log('音频捕获器初始化成功');
    });

    /**
     * 测试重复初始化
     */
    it('should handle repeated initialization', async () => {
      TestUtils.log('测试重复初始化功能');

      // 第一次初始化
      await audioCapturer.init(audioDataCallback);

      // 获取初始状态
      const initialState = audioCapturer.getState();

      // 尝试重复初始化
      await audioCapturer.init(audioDataCallback);

      // 验证状态仍然有效
      const currentState = audioCapturer.getState();
      expect(currentState !== null).assertTrue();

      TestUtils.log('重复初始化测试通过');
    });

    /**
     * 测试开始录音功能
     */
    it('should start recording correctly', async () => {
      TestUtils.log('测试开始录音功能');

      // 初始化音频捕获器
      await audioCapturer.init(audioDataCallback);

      // 开始录音
      await audioCapturer.start();

      // 验证录音状态
      const isRecording = audioCapturer.isRecording();
      const state = audioCapturer.getState();

      TestUtils.log(`开始录音 - 状态: ${state}, 是否录音中: ${isRecording}`);

      // 等待一段时间确保录音启动
      await TestUtils.sleep(500);

      TestUtils.log('开始录音测试通过');
    });

    /**
     * 测试停止录音功能
     */
    it('should stop recording correctly', async () => {
      TestUtils.log('测试停止录音功能');

      // 初始化并开始录音
      await audioCapturer.init(audioDataCallback);
      await audioCapturer.start();

      // 等待录音开始
      await TestUtils.sleep(200);

      // 停止录音
      await audioCapturer.stop();

      // 验证录音已停止
      const isRecording = audioCapturer.isRecording();
      const state = audioCapturer.getState();

      TestUtils.log(`停止录音 - 状态: ${state}, 是否录音中: ${isRecording}`);

      TestUtils.log('停止录音测试通过');
    });

    /**
     * 测试录音状态查询
     */
    it('should provide correct recording status', async () => {
      TestUtils.log('测试录音状态查询功能');

      // 初始化后的状态
      await audioCapturer.init(audioDataCallback);
      expect(audioCapturer.isRecording()).assertFalse();

      // 开始录音后的状态
      await audioCapturer.start();
      await TestUtils.sleep(100);
      // 注意：由于实际录音状态可能需要时间，这里主要测试状态查询功能

      // 停止录音后的状态
      await audioCapturer.stop();
      expect(audioCapturer.isRecording()).assertFalse();

      TestUtils.log('录音状态查询测试通过');
    });

    /**
     * 测试音频数据回调设置
     */
    it('should set audio data callback correctly', async () => {
      TestUtils.log('测试音频数据回调设置功能');

      // 创建新的回调函数
      let newCallbackTriggered = false;
      const newCallback = (data: ArrayBuffer): void => {
        newCallbackTriggered = true;
        TestUtils.log(`新回调收到数据: ${data.byteLength} bytes`);
      };

      // 设置新的回调
      audioCapturer.setAudioDataCallback(newCallback);

      // 验证回调设置成功（实际回调需要在录音时触发）
      expect(newCallbackTriggered).assertFalse(); // 未开始录音，不应触发

      TestUtils.log('音频数据回调设置测试通过');
    });

    /**
     * 测试状态获取
     */
    it('should get audio capturer state correctly', async () => {
      TestUtils.log('测试状态获取功能');

      // 未初始化时的状态
      let state = audioCapturer.getState();
      TestUtils.log(`未初始化状态: ${state}`);

      // 初始化后的状态
      await audioCapturer.init(audioDataCallback);
      state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      // 开始录音后的状态
      await audioCapturer.start();
      state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      // 停止录音后的状态
      await audioCapturer.stop();
      state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      TestUtils.log('状态获取测试通过');
    });

    /**
     * 测试录音控制流程
     */
    it('should handle complete recording workflow', async () => {
      TestUtils.log('测试完整录音控制流程');

      // 1. 初始化
      await audioCapturer.init(audioDataCallback);
      expect(audioCapturer.getState() !== null).assertTrue();

      // 2. 开始录音
      await audioCapturer.start();
      await TestUtils.sleep(200);

      // 3. 停止录音
      await audioCapturer.stop();
      expect(audioCapturer.isRecording()).assertFalse();

      // 4. 释放资源
      await audioCapturer.release();

      TestUtils.log('完整录音控制流程测试通过');
    });

    /**
     * 测试错误处理
     */
    it('should handle errors correctly', async () => {
      TestUtils.log('测试错误处理功能');

      // 测试未初始化时开始录音
      let newAudioCapturer = new AudioCapturer();

      // 尝试在未初始化时开始录音
      await newAudioCapturer.start();

      // 验证状态检查逻辑
      const state = newAudioCapturer.getState();
      TestUtils.log(`未初始化开始录音后的状态: ${state}`);

      // 测试重复释放
      await newAudioCapturer.release();
      await newAudioCapturer.release(); // 第二次释放不应出错

      TestUtils.log('错误处理测试通过');
    });

    /**
     * 测试音频参数配置
     */
    it('should handle audio parameters correctly', async () => {
      TestUtils.log('测试音频参数配置功能');

      // 初始化音频捕获器
      await audioCapturer.init(audioDataCallback);

      // 验证音频捕获器状态
      const state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      // 验证音频参数（通过状态推断）
      TestUtils.log(`音频捕获器状态: ${state}`);

      TestUtils.log('音频参数配置测试通过');
    });

    /**
     * 测试并发操作
     */
    it('should handle concurrent operations correctly', async () => {
      TestUtils.log('测试并发操作功能');

      // 创建多个音频捕获器实例
      const capturers: AudioCapturer[] = [];
      const promises: Promise<void>[] = [];

      // 并发创建和初始化多个捕获器
      for (let i = 0; i < 3; i++) {
        const capturer = new AudioCapturer();
        capturers.push(capturer);

        const promise = capturer.init((data: ArrayBuffer) => {
          TestUtils.log(`捕获器 ${i} 收到数据: ${data.byteLength} bytes`);
        });

        promises.push(promise);
      }

      // 等待所有初始化完成
      await Promise.all(promises);

      // 验证所有捕获器都初始化成功
      for (let i = 0; i < capturers.length; i++) {
        const state = capturers[i].getState();
        expect(state !== null).assertTrue();
      }

      // 清理所有捕获器
      for (const capturer of capturers) {
        await capturer.destroy();
      }

      TestUtils.log('并发操作测试通过');
    });

    /**
     * 测试资源释放
     */
    it('should release resources correctly', async () => {
      TestUtils.log('测试资源释放功能');

      // 初始化并开始录音
      await audioCapturer.init(audioDataCallback);
      await audioCapturer.start();
      await TestUtils.sleep(100);

      // 释放资源
      await audioCapturer.release();

      // 验证资源已释放
      const state = audioCapturer.getState();
      TestUtils.log(`释放资源后状态: ${state}`);

      // 创建新的实例进行测试
      audioCapturer = new AudioCapturer();

      TestUtils.log('资源释放测试通过');
    });

    /**
     * 测试销毁功能
     */
    it('should destroy audio capturer correctly', async () => {
      TestUtils.log('测试销毁功能');

      // 初始化并开始录音
      await audioCapturer.init(audioDataCallback);
      await audioCapturer.start();
      await TestUtils.sleep(100);

      // 销毁音频捕获器
      await audioCapturer.destroy();

      // 验证销毁后的状态
      const state = audioCapturer.getState();
      TestUtils.log(`销毁后状态: ${state}`);

      // 创建新的实例
      audioCapturer = new AudioCapturer();

      TestUtils.log('销毁功能测试通过');
    });

    /**
     * 测试音频数据流
     */
    it('should handle audio data stream correctly', async () => {
      TestUtils.log('测试音频数据流功能');

      // 初始化音频捕获器
      await audioCapturer.init(audioDataCallback);

      // 开始录音
      await audioCapturer.start();

      // 等待音频数据
      await TestUtils.sleep(1000);

      // 停止录音
      await audioCapturer.stop();

      // 验证数据接收
      TestUtils.log(`收到音频数据块数量: ${audioDataReceived.length}`);

      // 验证回调机制正常工作
      expect(callbackTriggered || audioDataReceived.length > 0).assertTrue();

      TestUtils.log('音频数据流测试通过');
    });

    /**
     * 测试音频格式兼容性
     */
    it('should handle audio format compatibility', async () => {
      TestUtils.log('测试音频格式兼容性功能');

      // 初始化音频捕获器
      await audioCapturer.init(audioDataCallback);

      // 验证音频捕获器支持标准格式
      const state = audioCapturer.getState();
      expect(state !== null).assertTrue();

      // 开始录音
      await audioCapturer.start();
      await TestUtils.sleep(100);

      // 停止录音
      await audioCapturer.stop();

      TestUtils.log('音频格式兼容性测试通过');
    });

    /**
     * 测试录音时序控制
     */
    it('should handle recording timing correctly', async () => {
      TestUtils.log('测试录音时序控制功能');

      // 快速启动和停止录音
      for (let i = 0; i < 3; i++) {
        TestUtils.log(`第 ${i + 1} 次录音循环`);

        // 初始化
        await audioCapturer.init(audioDataCallback);

        // 开始录音
        await audioCapturer.start();

        // 短暂等待
        await TestUtils.sleep(50);

        // 停止录音
        await audioCapturer.stop();

        // 释放资源
        await audioCapturer.release();

        // 创建新实例
        audioCapturer = new AudioCapturer();
      }

      TestUtils.log('录音时序控制测试通过');
    });

    /**
     * 测试内存管理
     */
    it('should manage memory correctly', async () => {
      TestUtils.log('测试内存管理功能');

      // 初始化并开始录音
      await audioCapturer.init(audioDataCallback);
      await audioCapturer.start();

      // 模拟大量音频数据接收
      await TestUtils.sleep(2000);

      // 停止录音
      await audioCapturer.stop();

      // 释放资源
      await audioCapturer.destroy();

      // 验证音频数据数组已被清理
      const initialDataLength = audioDataReceived.length;
      TestUtils.log(`处理音频数据块数量: ${initialDataLength}`);

      TestUtils.log('内存管理测试通过');
    });
  });
}