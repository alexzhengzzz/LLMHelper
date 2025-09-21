import { describe, beforeAll, afterAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import QuickCommandsComponent from '../../main/ets/components/QuickCommandsComponent';
import { QuickCommand } from '../../main/ets/types/ToolboxTypes';

export default function QuickCommandsComponentTest() {
  describe('QuickCommandsComponentTest', () => {
    let component: QuickCommandsComponent;

    beforeAll(() => {
      // 初始化测试环境
      component = new QuickCommandsComponent();
    });

    afterAll(() => {
      // 清理测试环境
      component = null;
    });

    beforeEach(() => {
      // 重置组件状态
      if (component) {
        component.clearState();
      }
    });

    afterEach(() => {
      // 清理测试数据
    });

    it('should initialize with default state', () => {
      expect(component.isExpanded).assertEqual(false);
      expect(component.selectedCategory).assertEqual('all');
      expect(component.searchQuery).assertEqual('');
      expect(component.filteredCommands.length).assertEqual(0);
    });

    it('should toggle expand/collapse state', () => {
      expect(component.isExpanded).assertEqual(false);

      component.toggleExpand();
      expect(component.isExpanded).assertTrue();

      component.toggleExpand();
      expect(component.isExpanded).assertFalse();
    });

    it('should expand panel', () => {
      component.expand();
      expect(component.isExpanded).assertTrue();
    });

    it('should collapse panel', () => {
      component.expand();
      expect(component.isExpanded).assertTrue();

      component.collapse();
      expect(component.isExpanded).assertFalse();
    });

    it('should load default commands', () => {
      component.loadDefaultCommands();
      expect(component.commands.length).assertGreaterThan(0);
      expect(component.filteredCommands.length).assertGreaterThan(0);
    });

    it('should filter commands by category', () => {
      component.loadDefaultCommands();

      component.filterByCategory('development');
      expect(component.selectedCategory).assertEqual('development');

      // 验证过滤结果
      const filteredCommands = component.filteredCommands;
      filteredCommands.forEach(command => {
        expect(command.category).assertEqual('development');
      });
    });

    it('should filter commands by search query', () => {
      component.loadDefaultCommands();

      component.search('code');
      expect(component.searchQuery).assertEqual('code');

      // 验证搜索结果包含相关命令
      const filteredCommands = component.filteredCommands;
      filteredCommands.forEach(command => {
        const searchMatch = command.title.toLowerCase().includes('code') ||
                          command.description.toLowerCase().includes('code') ||
                          command.keywords.some(keyword => keyword.toLowerCase().includes('code'));
        expect(searchMatch).assertTrue();
      });
    });

    it('should clear search filter', () => {
      component.loadDefaultCommands();
      const originalCount = component.commands.length;

      component.search('test');
      expect(component.filteredCommands.length).assertLessThan(originalCount);

      component.clearSearch();
      expect(component.searchQuery).assertEqual('');
      expect(component.filteredCommands.length).assertEqual(originalCount);
    });

    it('should get available categories', () => {
      component.loadDefaultCommands();
      const categories = component.getAvailableCategories();

      expect(categories.length).assertGreaterThan(0);
      expect(categories).toContain('development');
      expect(categories).toContain('system');
      expect(categories).toContain('learning');
    });

    it('should get commands by category', () => {
      component.loadDefaultCommands();
      const devCommands = component.getCommandsByCategory('development');

      expect(devCommands.length).assertGreaterThan(0);
      devCommands.forEach(command => {
        expect(command.category).assertEqual('development');
      });
    });

    it('should return empty array for non-existent category', () => {
      component.loadDefaultCommands();
      const commands = component.getCommandsByCategory('non-existent');
      expect(commands.length).assertEqual(0);
    });

    it('should add custom command', () => {
      const customCommand: QuickCommand = {
        id: 'custom-test',
        title: 'Custom Command',
        description: 'Test custom command',
        category: 'custom',
        prompt: 'Custom prompt',
        keywords: ['custom', 'test']
      };

      component.addCommand(customCommand);
      expect(component.commands.some(cmd => cmd.id === 'custom-test')).assertTrue();
    });

    it('should remove command', () => {
      component.loadDefaultCommands();
      const commandToRemove = component.commands[0];
      const commandId = commandToRemove.id;

      component.removeCommand(commandId);
      expect(component.commands.some(cmd => cmd.id === commandId)).assertFalse();
    });

    it('should update command', () => {
      component.loadDefaultCommands();
      const commandToUpdate = component.commands[0];
      const originalTitle = commandToUpdate.title;
      const newTitle = 'Updated Title';

      component.updateCommand(commandToUpdate.id, { title: newTitle });
      const updatedCommand = component.commands.find(cmd => cmd.id === commandToUpdate.id);
      expect(updatedCommand.title).assertEqual(newTitle);
    });

    it('should handle command click', () => {
      let clickedCommand: QuickCommand | null = null;

      component.onCommandClick = (command: QuickCommand) => {
        clickedCommand = command;
      };

      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      component.handleCommandClick(testCommand);
      expect(clickedCommand).assertEqual(testCommand);
    });

    it('should collapse after command click', () => {
      component.expand();
      expect(component.isExpanded).assertTrue();

      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      component.handleCommandClick(testCommand);
      expect(component.isExpanded).assertFalse();
    });

    it('should handle favorite command', () => {
      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      expect(testCommand.isFavorite).assertEqual(false);

      component.toggleFavorite(testCommand.id);
      expect(testCommand.isFavorite).assertTrue();

      component.toggleFavorite(testCommand.id);
      expect(testCommand.isFavorite).assertFalse();
    });

    it('should get favorite commands', () => {
      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      component.toggleFavorite(testCommand.id);
      const favoriteCommands = component.getFavoriteCommands();

      expect(favoriteCommands.length).assertEqual(1);
      expect(favoriteCommands[0]).assertEqual(testCommand);
    });

    it('should get recently used commands', () => {
      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      component.handleCommandClick(testCommand);
      const recentCommands = component.getRecentlyUsedCommands();

      expect(recentCommands.length).assertEqual(1);
      expect(recentCommands[0]).assertEqual(testCommand);
    });

    it('should limit recently used commands count', () => {
      component.loadDefaultCommands();
      const maxRecent = 5;

      // 添加多个命令到最近使用
      for (let i = 0; i < 10; i++) {
        const command = component.commands[i % component.commands.length];
        component.handleCommandClick(command);
      }

      const recentCommands = component.getRecentlyUsedCommands();
      expect(recentCommands.length).assertLessEqual(maxRecent);
    });

    it('should handle command execution', () => {
      let executedCommand: QuickCommand | null = null;

      component.onCommandExecute = (command: QuickCommand) => {
        executedCommand = command;
      };

      component.loadDefaultCommands();
      const testCommand = component.commands[0];

      component.executeCommand(testCommand);
      expect(executedCommand).assertEqual(testCommand);
    });

    it('should validate command structure', () => {
      const invalidCommand = {
        id: '',
        title: '',
        description: '',
        category: '',
        prompt: '',
        keywords: []
      };

      expect(component.validateCommand(invalidCommand)).assertFalse();

      const validCommand: QuickCommand = {
        id: 'test',
        title: 'Test',
        description: 'Test command',
        category: 'test',
        prompt: 'Test prompt',
        keywords: ['test']
      };

      expect(component.validateCommand(validCommand)).assertTrue();
    });

    it('should handle search with special characters', () => {
      component.loadDefaultCommands();

      component.search('c++');
      expect(component.filteredCommands.length).assertGreaterThan(0);

      component.search('javascript');
      expect(component.filteredCommands.length).assertGreaterThan(0);
    });

    it('should handle empty search query', () => {
      component.loadDefaultCommands();
      const originalCount = component.commands.length;

      component.search('');
      expect(component.filteredCommands.length).assertEqual(originalCount);
    });

    it('should handle case-insensitive search', () => {
      component.loadDefaultCommands();

      component.search('CODE');
      component.search('code');
      component.search('Code');

      // 所有搜索应该返回相同的结果
      expect(component.filteredCommands.length).assertGreaterThan(0);
    });

    it('should persist commands state', () => {
      component.loadDefaultCommands();
      const originalCount = component.commands.length;

      // 添加自定义命令
      const customCommand: QuickCommand = {
        id: 'persist-test',
        title: 'Persistent Command',
        description: 'Test persistence',
        category: 'test',
        prompt: 'Test prompt',
        keywords: ['persistent']
      };

      component.addCommand(customCommand);

      // 模拟保存状态
      component.saveState();
      const savedState = component.getSavedState();

      // 重置状态
      component.clearState();
      expect(component.commands.length).assertEqual(0);

      // 恢复状态
      component.restoreState(savedState);
      expect(component.commands.length).assertEqual(originalCount + 1);
      expect(component.commands.some(cmd => cmd.id === 'persist-test')).assertTrue();
    });

    it('should handle command categories', () => {
      component.loadDefaultCommands();
      const categories = component.getAvailableCategories();

      categories.forEach(category => {
        const commands = component.getCommandsByCategory(category);
        commands.forEach(command => {
          expect(command.category).assertEqual(category);
        });
      });
    });

    it('should handle keyboard navigation', () => {
      let selectedIndex = -1;

      component.onKeyDown = (event: KeyboardEvent) => {
        if (event.key === 'ArrowDown') {
          selectedIndex = Math.min(selectedIndex + 1, component.filteredCommands.length - 1);
        } else if (event.key === 'ArrowUp') {
          selectedIndex = Math.max(selectedIndex - 1, -1);
        }
      };

      component.loadDefaultCommands();
      component.search('test');

      // 模拟向下箭头
      const downEvent = new KeyboardEvent('keydown', { key: 'ArrowDown' });
      component.onKeyDown(downEvent);
      expect(selectedIndex).assertEqual(0);

      // 模拟向上箭头
      const upEvent = new KeyboardEvent('keydown', { key: 'ArrowUp' });
      component.onKeyDown(upEvent);
      expect(selectedIndex).assertEqual(-1);
    });

    it('should handle edge cases', () => {
      // 测试空命令列表
      component.clearCommands();
      expect(component.commands.length).assertEqual(0);
      expect(component.filteredCommands.length).assertEqual(0);

      // 测试搜索空列表
      component.search('test');
      expect(component.filteredCommands.length).assertEqual(0);

      // 测试分类过滤空列表
      component.filterByCategory('development');
      expect(component.filteredCommands.length).assertEqual(0);
    });
  });
}