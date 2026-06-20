import { PricingService } from './pricing.service';

describe('PricingService', () => {
  const s = new PricingService();

  describe('Reserve fares', () => {
    it('same zone A→A = 20', () => expect(s.getFare('A', 'A', 'reserve', false)).toBe(20));
    it('A→B = 25', ()        => expect(s.getFare('A', 'B', 'reserve', false)).toBe(25));
    it('A→E = 35', ()        => expect(s.getFare('A', 'E', 'reserve', false)).toBe(35));
    it('E→A = 35 (symmetric)', () => expect(s.getFare('E', 'A', 'reserve', false)).toBe(35));
    it('B→D = 25', ()        => expect(s.getFare('B', 'D', 'reserve', false)).toBe(25));
    it('night +5: A→B = 30', () => expect(s.getFare('A', 'B', 'reserve', true)).toBe(30));
    it('night +5: A→E = 40', () => expect(s.getFare('A', 'E', 'reserve', true)).toBe(40));
  });

  describe('Share fares', () => {
    it('same zone A→A = 10', () => expect(s.getFare('A', 'A', 'share', false)).toBe(10));
    it('A→E = 15', ()          => expect(s.getFare('A', 'E', 'share', false)).toBe(15));
    it('E→A = 15 (symmetric)', () => expect(s.getFare('E', 'A', 'share', false)).toBe(15));
    it('B→E = 12', ()          => expect(s.getFare('B', 'E', 'share', false)).toBe(12));
    it('C→E = 10', ()          => expect(s.getFare('C', 'E', 'share', false)).toBe(10));
    it('night +5: A→E = 20',   () => expect(s.getFare('A', 'E', 'share', true)).toBe(20));
  });

  describe('resolveZone', () => {
    it('zone A center → A', () => expect(s.resolveZone(29.6039, 78.3365)).toBe('A'));
    it('zone C center → C', () => expect(s.resolveZone(29.6125, 78.3406)).toBe('C'));
    it('zone E center → E', () => expect(s.resolveZone(29.6105, 78.3522)).toBe('E'));
  });
});
